import AVFoundation
import CoreImage
import CoreGraphics
import CoreVideo
import CoreLocation

enum VideoComposerError: Error, LocalizedError {
    case noVideoTrack
    case exporterSetupFailed
    case exportFailed(Error?)
    case exportCancelled
    case exportIncomplete(AVAssetExportSession.Status)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "No video track found"
        case .exporterSetupFailed: return "Failed to create AVAssetExportSession"
        case .exportFailed(let e): return "Export failed: \(Self.describe(error: e))"
        case .exportCancelled: return "Export cancelled"
        case .exportIncomplete(let s): return "Export incomplete: status=\(s.rawValue)"
        }
    }

    private static func describe(error: Error?) -> String {
        guard let e = error as NSError? else { return "unknown" }
        return "\(e.domain)(\(e.code)) \(e.localizedDescription) | userInfo: \(e.userInfo)"
    }
}

struct VideoComposeResult {
    let outputURL: URL
    let isHDR: Bool
    let transferFunction: String?
    let colorPrimaries: String?
    let yCbCrMatrix: String?
}

/// HDR (HLG/PQ) を保持したまま動画にオーバーレイを合成するプロトタイプ実装。
/// `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)` + `AVAssetExportSession`
/// により、HDRパイプラインを AVFoundation 側に委ねる。
enum VideoComposer {

    static func compose(
        inputURL: URL,
        overlay: CGImage,
        outputURL: URL,
        progress: (@Sendable (Float) -> Void)? = nil
    ) async throws -> VideoComposeResult {
        try await compose(
            inputURL: inputURL,
            overlayBuilder: { _ in overlay },
            outputURL: outputURL,
            progress: progress
        )
    }

    /// オーバーレイを request.sourceImage の実サイズに合わせて遅延生成するバリアント。
    /// 動画の縦撮り/横撮り・トランスフォーム適用後のサイズを正しく扱うため、
    /// `overlayBuilder` は実際の描画キャンバスサイズで呼ばれる。
    static func compose(
        inputURL: URL,
        overlayBuilder: @escaping @Sendable (CGSize) -> CGImage?,
        outputURL: URL,
        progress: (@Sendable (Float) -> Void)? = nil
    ) async throws -> VideoComposeResult {
        let asset = AVURLAsset(url: inputURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoComposerError.noVideoTrack
        }

        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        let (primaries, transfer, matrix) = extractColorAttachments(from: formatDescriptions)
        let isHDR = transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String)
                 || transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String)

        let composition = try await makeVideoComposition(asset: asset, overlayBuilder: overlayBuilder)

        try? FileManager.default.removeItem(at: outputURL)

        // HDR入力ならHEVCプリセット（HDR維持）、SDRなら互換プリセット
        let preset = isHDR
            ? AVAssetExportPresetHEVCHighestQuality
            : AVAssetExportPresetHighestQuality
        guard let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoComposerError.exporterSetupFailed
        }
        exporter.videoComposition = composition
        exporter.shouldOptimizeForNetworkUse = false

        let progressTask: Task<Void, Never>? = progress.map { cb in
            Task {
                for await state in exporter.states(updateInterval: 0.2) {
                    if Task.isCancelled { return }
                    switch state {
                    case .exporting(let progress):
                        cb(Float(progress.fractionCompleted))
                    default:
                        break
                    }
                }
            }
        }
        defer { progressTask?.cancel() }

        do {
            try await exporter.export(to: outputURL, as: .mov)
        } catch {
            throw VideoComposerError.exportFailed(error)
        }

        // 出力動画のメタデータを再取得
        let outAsset = AVURLAsset(url: outputURL)
        var outPrimaries = primaries
        var outTransfer = transfer
        var outMatrix = matrix
        var outIsHDR = isHDR
        if let outTrack = try? await outAsset.loadTracks(withMediaType: .video).first,
           let outFormats = try? await outTrack.load(.formatDescriptions) {
            let resolved = extractColorAttachments(from: outFormats)
            outPrimaries = resolved.primaries ?? primaries
            outTransfer = resolved.transfer ?? transfer
            outMatrix = resolved.matrix ?? matrix
            outIsHDR = outTransfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String)
                    || outTransfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String)
        }

        return VideoComposeResult(
            outputURL: outputURL,
            isHDR: outIsHDR,
            transferFunction: outTransfer,
            colorPrimaries: outPrimaries,
            yCbCrMatrix: outMatrix
        )
    }

    /// 動画中央のフレームを取得し、ルート描画領域の背景明度をサンプルする。
    /// オーバーレイのルート縁取り色を背景に応じて切り替えるための値。
    static func sampleMiddleFrameBrightness(
        url: URL,
        routeCoordinates: [CLLocationCoordinate2D]
    ) async -> CGFloat? {
        guard !routeCoordinates.isEmpty else { return nil }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        do {
            let duration = try await asset.load(.duration)
            let mid = CMTimeMultiplyByFloat64(duration, multiplier: 0.5)
            let (cgImage, _) = try await generator.image(at: mid)
            let ci = CIImage(cgImage: cgImage)
            return ImageComposer.sampleRouteAreaBrightness(image: ci, routeCoordinates: routeCoordinates)
        } catch {
            return nil
        }
    }

    /// プレビュー再生 (AVPlayerItem.videoComposition) と書き出しの両方で同じ合成結果を得るためのヘルパー。
    static func makeVideoComposition(
        asset: AVAsset,
        overlayBuilder: @escaping @Sendable (CGSize) -> CGImage?
    ) async throws -> AVVideoComposition {
        let cache = OverlayCache()
        return try await AVMutableVideoComposition.videoComposition(with: asset) { request in
            let source = request.sourceImage
            let canvasSize = source.extent.size
            let overlayCI = cache.image(for: canvasSize, builder: overlayBuilder)
            if let overlayCI {
                let composited = overlayCI.composited(over: source)
                request.finish(with: composited, context: nil)
            } else {
                request.finish(with: source, context: nil)
            }
        }
    }

    // MARK: - Helpers

    private static func extractColorAttachments(
        from formatDescriptions: [CMFormatDescription]
    ) -> (primaries: String?, transfer: String?, matrix: String?) {
        guard let fmt = formatDescriptions.first else { return (nil, nil, nil) }
        let ext = CMFormatDescriptionGetExtensions(fmt) as? [String: Any]
        let primaries = ext?[kCVImageBufferColorPrimariesKey as String] as? String
        let transfer = ext?[kCVImageBufferTransferFunctionKey as String] as? String
        let matrix = ext?[kCVImageBufferYCbCrMatrixKey as String] as? String
        return (primaries, transfer, matrix)
    }

}

/// `applyingCIFiltersWithHandler` のフレームハンドラは複数回呼ばれるので、
/// 同じキャンバスサイズに対するオーバーレイCIImageをキャッシュする。
private final class OverlayCache: @unchecked Sendable {
    private var cachedSize: CGSize = .zero
    private var cachedImage: CIImage?
    private let lock = NSLock()

    func image(for size: CGSize, builder: @Sendable (CGSize) -> CGImage?) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        if cachedSize == size, let cachedImage {
            return cachedImage
        }
        guard let cg = builder(size) else { return nil }
        let ci = CIImage(cgImage: cg)
        cachedSize = size
        cachedImage = ci
        return ci
    }
}
