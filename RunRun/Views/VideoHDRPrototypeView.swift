#if DEBUG
import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import Photos
import UIKit
import CoreImage
import CoreLocation
import UniformTypeIdentifiers

/// PhotosPickerからオリジナル形式のまま動画を取得するためのTransferable。
/// Dataで取得するとiOSがSDRにトランスコードするため、URL経由でコピーする。
private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { item in
            SentTransferredFile(item.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("hdr-input-\(UUID().uuidString)")
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVideo(url: dest)
        }
    }
}

/// HDR動画にオーバーレイを合成するプロトタイプ画面（DEBUGのみ）。
/// - 入力動画をPhotosから選択
/// - 拡張レンジ白で "12.5 km" のオーバーレイを合成
/// - 入出力の色空間メタデータを表示
/// - 結果をPhotosに保存して実機で確認
struct VideoHDRPrototypeView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputURL: URL?
    @State private var inputInfo: String = ""
    @State private var outputURL: URL?
    @State private var outputInfo: String = ""
    @State private var progress: Float = 0
    @State private var status: String = ""
    @State private var isWorking = false

    // プレビュー & 合成で共有するオーバーレイ設定
    @State private var brightness: CGFloat?
    @State private var avPlayer: AVPlayer?

    private let record = MockDataProvider.runDetail
    private let routeCoords = MockDataProvider.imperialPalaceRouteSegments.flatMap { $0.coordinates }
    private let options = ExportOptions()

    var body: some View {
        Form {
            Section("Input") {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    preferredItemEncoding: .current
                ) {
                    Label(inputURL == nil ? "Select Video" : "Change Video", systemImage: "video")
                }
                if !inputInfo.isEmpty {
                    Text(inputInfo)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let player = avPlayer {
                Section("Preview") {
                    VideoPlayer(player: player)
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets())
                }
            }

            if inputURL != nil {
                Section("Compose") {
                    Button("Compose with HDR Overlay") {
                        Task { await runCompose() }
                    }
                    .disabled(isWorking)

                    if isWorking {
                        ProgressView(value: progress)
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.caption.monospacedDigit())
                    }
                    if !status.isEmpty {
                        Text(status).font(.caption)
                    }
                }
            }

            if outputURL != nil {
                Section("Output") {
                    Text(outputInfo)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Save to Photos") {
                        Task { await saveToPhotos() }
                    }
                }
            }
        }
        .navigationTitle("HDR Video Prototype")
        .onChange(of: selectedItem) { _, newValue in
            Task { await loadVideo(item: newValue) }
        }
        .onDisappear {
            avPlayer?.pause()
        }
    }

    // MARK: - Actions

    private func loadVideo(item: PhotosPickerItem?) async {
        guard let item else { return }
        status = "Loading..."
        avPlayer?.pause()
        avPlayer = nil
        do {
            guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                status = "No data"
                return
            }
            inputURL = picked.url
            outputURL = nil
            outputInfo = ""
            progress = 0
            inputInfo = await describe(url: picked.url)

            // 中央フレームから明度をサンプルし、その値でプレビューを構築
            brightness = await VideoComposer.sampleMiddleFrameBrightness(
                url: picked.url,
                routeCoordinates: options.showRoute ? routeCoords : []
            )
            await setupPlayer(url: picked.url)
            status = ""
        } catch {
            status = "Load error: \(error.localizedDescription)"
        }
    }

    private func setupPlayer(url: URL) async {
        let builder = makeOverlayBuilder()
        do {
            let asset = AVURLAsset(url: url)
            let composition = try await VideoComposer.makeVideoComposition(
                asset: asset,
                overlayBuilder: builder
            )
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = composition
            avPlayer = AVPlayer(playerItem: item)
        } catch {
            status = "Preview error: \(error.localizedDescription)"
        }
    }

    private func makeOverlayBuilder() -> @Sendable (CGSize) -> CGImage? {
        let record = self.record
        let options = self.options
        let routeCoords = self.routeCoords
        let brightness = self.brightness
        return { canvasSize in
            ImageComposer.makeOverlayCGImage(
                size: canvasSize,
                record: record,
                options: options,
                routeCoordinates: routeCoords,
                routeAreaBrightness: brightness,
                centered: false
            )
        }
    }

    private func runCompose() async {
        guard let inputURL else { return }
        isWorking = true
        defer { isWorking = false }
        progress = 0
        status = "Composing..."
        outputURL = nil
        outputInfo = ""

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hdr-composed-\(UUID().uuidString)")
            .appendingPathExtension("mov")

        do {
            let result = try await VideoComposer.compose(
                inputURL: inputURL,
                overlayBuilder: makeOverlayBuilder(),
                outputURL: outURL,
                progress: { p in
                    Task { @MainActor in self.progress = p }
                }
            )
            outputURL = result.outputURL
            outputInfo = """
            isHDR: \(result.isHDR)
            primaries: \(result.colorPrimaries ?? "-")
            transfer: \(result.transferFunction ?? "-")
            matrix: \(result.yCbCrMatrix ?? "-")
            file: \(Self.fileSize(url: result.outputURL))
            """
            status = "Done"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    private func saveToPhotos() async {
        guard let outputURL else { return }
        guard await PhotoLibraryService.ensureAuthorization() else {
            status = "Photos permission denied"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .video, fileURL: outputURL, options: nil)
            }
            status = "Saved to Photos"
        } catch {
            status = "Save error: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func describe(url: URL) async -> String {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                return "No video track"
            }
            let formats = try await track.load(.formatDescriptions)
            let size = try await track.load(.naturalSize)
            let duration = try await asset.load(.duration)
            let frameRate = try await track.load(.nominalFrameRate)

            var primaries: String?
            var transfer: String?
            var matrix: String?
            if let fmt = formats.first {
                let ext = CMFormatDescriptionGetExtensions(fmt) as? [String: Any]
                primaries = ext?[kCVImageBufferColorPrimariesKey as String] as? String
                transfer = ext?[kCVImageBufferTransferFunctionKey as String] as? String
                matrix = ext?[kCVImageBufferYCbCrMatrixKey as String] as? String
            }
            return """
            size: \(Int(size.width))x\(Int(size.height))
            duration: \(String(format: "%.1f", CMTimeGetSeconds(duration)))s @ \(String(format: "%.1f", frameRate))fps
            primaries: \(primaries ?? "-")
            transfer: \(transfer ?? "-")
            matrix: \(matrix ?? "-")
            file: \(Self.fileSize(url: url))
            """
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private static func fileSize(url: URL) -> String {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

}
#endif
