import SwiftUI
import CoreImage
import UIKit

// MARK: - Image Composer (WWDC 2024 Strategy B - HDR対応)

enum ImageComposer {
    /// HDR Gainmapを保持したまま画像を合成してHEIF Dataを返す (WWDC 2024 Strategy A)
    /// - SDRとHDRの両方に同じテキストを描画
    /// - 両者の対応関係を維持してGain Mapを再計算
    /// - PHPhotoLibraryに直接渡すためにDataを返す
    static func composeAsHEIF(imageData: Data, record: RunningRecord, options: ExportOptions) async -> Data? {
        // 1. SDR画像を読み込み（向き自動適用）
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        // 2. テキストオーバーレイ画像を作成（一度だけ）
        let textOverlay = createTextOverlay(size: sdrImage.extent.size, record: record, options: options)

        // 3. SDRにテキストを合成
        let sdrWithText: CIImage
        if let overlay = textOverlay {
            sdrWithText = overlay.composited(over: sdrImage)
        } else {
            sdrWithText = sdrImage
        }

        // 4. iOS 17+: HDRにも同じテキストを合成
        var hdrWithText: CIImage?
        if #available(iOS 17.0, *) {
            if let hdrImage = CIImage(data: imageData, options: [
                .applyOrientationProperty: true,
                .expandToHDR: true
            ]) {
                if let overlay = textOverlay {
                    hdrWithText = overlay.composited(over: hdrImage)
                } else {
                    hdrWithText = hdrImage
                }
            }
        }

        // 5. HEIF形式で出力（両方のレイヤーを渡す）
        return saveAsHEIFData(sdrImage: sdrWithText, hdrImage: hdrWithText)
    }

    /// テキストオーバーレイ画像を作成
    private static func createTextOverlay(size: CGSize, record: RunningRecord, options: ExportOptions) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            drawTextOverlay(width: size.width, height: size.height, record: record, options: options)
        }

        // premultiplied alphaを正しく処理するためCGImageから作成
        guard let cgImage = textUIImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage, options: [.applyOrientationProperty: true])
    }

    /// HEIF形式のDataを生成（HDR対応 - ファイル経由）
    private static func saveAsHEIFData(sdrImage: CIImage, hdrImage: CIImage?) -> Data? {
        let context = CIContext()
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
            return nil
        }

        // 一時ファイルに書き出し（writeHEIFRepresentationを使用）
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // iOS 17+: HDR参照を設定するとCore ImageがGain Mapを再計算
        var options: [CIImageRepresentationOption: Any] = [:]
        if #available(iOS 17.0, *), let hdr = hdrImage {
            options[.hdrImage] = hdr
        }

        // HDR用に10bitフォーマットを使用（アルファなし）
        let format: CIFormat = .RGB10

        do {
            // writeHEIFRepresentationでファイルに直接書き出し
            try context.writeHEIFRepresentation(
                of: sdrImage,
                to: tempURL,
                format: format,
                colorSpace: colorSpace,
                options: options
            )

            // ファイルからDataを読み込んで返す（UIImageに変換しない）
            return try Data(contentsOf: tempURL)
        } catch {
            print("HEIF write error: \(error)")

            // フォールバック: オプションなしで再試行
            do {
                try context.writeHEIFRepresentation(
                    of: sdrImage,
                    to: tempURL,
                    format: format,
                    colorSpace: colorSpace,
                    options: [:]
                )
                return try Data(contentsOf: tempURL)
            } catch {
                return nil
            }
        }
    }

    /// テキストオーバーレイを描画（ヒーローレイアウト）
    private static func drawTextOverlay(width: CGFloat, height: CGFloat, record: RunningRecord, options: ExportOptions) {
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let padding = baseFontSize * 0.8

        // フォントサイズのバリエーション
        let heroFont = UIFont.rounded(ofSize: baseFontSize * 1.4, weight: .bold)      // 距離の数値
        let unitFont = UIFont.rounded(ofSize: baseFontSize * 0.8, weight: .medium)    // 単位
        let subFont = UIFont.rounded(ofSize: baseFontSize * 0.9, weight: .semibold)   // 時間・ペース
        let metaFont = UIFont.rounded(ofSize: baseFontSize * 0.85, weight: .regular)  // 日付・その他

        var yOffset = height - padding
        let x = width - padding

        // === 下から上に描画 ===

        // 1. アプリロゴ（画像・HDRコントラスト調整）
        let logoHeight = baseFontSize * 2.0
        if let logo = UIImage(named: "Logo") {
            let logoAspect = logo.size.width / logo.size.height
            let logoWidth = logoHeight * logoAspect
            let logoRect = CGRect(x: x - logoWidth, y: yOffset - logoHeight, width: logoWidth, height: logoHeight)

            // 少し小さめの角丸にクリップ（白縁を隠す）
            let inset = logoHeight * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            let cornerRadius = clipRect.height * 0.22
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.saveGState()
                UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius).addClip()
            }

            // ロゴをコントラスト強調して描画
            if let ciLogo = CIImage(image: logo),
               let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)  // コントラスト強調
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)  // 少し明るく
                filter.setValue(1.4, forKey: kCIInputSaturationKey)  // 彩度を上げる
                if let output = filter.outputImage {
                    let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!])
                    if let cgImage = context.createCGImage(output, from: output.extent) {
                        UIImage(cgImage: cgImage).draw(in: logoRect)
                    } else {
                        logo.draw(in: logoRect)
                    }
                } else {
                    logo.draw(in: logoRect)
                }
            } else {
                logo.draw(in: logoRect)
            }

            // クリップを解除
            UIGraphicsGetCurrentContext()?.restoreGState()

            yOffset -= logoHeight + baseFontSize * 0.3
        }

        // 2. 追加情報（カロリー、心拍、歩数）
        var metaItems: [String] = []
        if options.showCalories, let cal = record.formattedCalories {
            metaItems.append(cal)
        }
        if options.showHeartRate, let hr = record.formattedAverageHeartRate {
            metaItems.append(hr)
        }
        if options.showSteps, let steps = record.formattedStepCount {
            metaItems.append(steps)
        }
        if !metaItems.isEmpty {
            let metaText = metaItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(metaText, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 3. 日付と時間（別々に処理）
        var dateTimeItems: [String] = []
        if options.showDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
            dateTimeItems.append(dateFormatter.string(from: record.date))
        }
        if options.showStartTime {
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale.current
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            dateTimeItems.append(timeFormatter.string(from: record.date))
        }
        if !dateTimeItems.isEmpty {
            let dateTimeText = dateTimeItems.joined(separator: " · ")
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(dateTimeText, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 4. 時間・ペース（1行にまとめる）
        if options.showDuration || options.showPace {
            var subItems: [String] = []
            if options.showDuration {
                subItems.append(record.formattedDuration)
            }
            if options.showPace {
                subItems.append(record.formattedPace)
            }
            let subText = subItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.5
            drawOutlinedText(subText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 5. 距離（ヒーロー表示: 数値と単位を分離）
        if options.showDistance {
            // 単位
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(UnitFormatter.distanceUnit, at: CGPoint(x: x, y: yOffset), font: unitFont)

            // 数値（大きく）
            let distanceValue = UnitFormatter.formatDistanceValue(record.distanceInKilometers, decimals: 2)
            yOffset -= baseFontSize * 1.6
            drawOutlinedText(distanceValue, at: CGPoint(x: x, y: yOffset), font: heroFont)
        }
    }

    private static func drawOutlinedText(_ text: String, at point: CGPoint, font: UIFont) {
        let strokeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        // HDR対応の明るい白（輝度2.0）
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let hdrWhite = CGColor(colorSpace: colorSpace, components: [2.0, 2.0, 2.0, 1.0])!
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(cgColor: hdrWhite)
        ]

        let textSize = (text as NSString).size(withAttributes: fillAttributes)
        let drawPoint = CGPoint(x: point.x - textSize.width, y: point.y)

        let outlineWidth: CGFloat = max(2, font.pointSize * 0.05)
        let offsets: [CGPoint] = [
            CGPoint(x: -outlineWidth, y: -outlineWidth),
            CGPoint(x: outlineWidth, y: -outlineWidth),
            CGPoint(x: -outlineWidth, y: outlineWidth),
            CGPoint(x: outlineWidth, y: outlineWidth),
            CGPoint(x: -outlineWidth, y: 0),
            CGPoint(x: outlineWidth, y: 0),
            CGPoint(x: 0, y: -outlineWidth),
            CGPoint(x: 0, y: outlineWidth)
        ]

        for offset in offsets {
            let offsetPoint = CGPoint(x: drawPoint.x + offset.x, y: drawPoint.y + offset.y)
            (text as NSString).draw(at: offsetPoint, withAttributes: strokeAttributes)
        }
        (text as NSString).draw(at: drawPoint, withAttributes: fillAttributes)
    }

    // MARK: - Monthly Stats Composition

    /// 月間統計画像を合成
    static func composeMonthlyStats(imageData: Data, shareData: MonthlyShareData, options: MonthExportOptions) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createMonthlyTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options)

        let sdrWithText: CIImage
        if let overlay = textOverlay {
            sdrWithText = overlay.composited(over: sdrImage)
        } else {
            sdrWithText = sdrImage
        }

        var hdrWithText: CIImage?
        if #available(iOS 17.0, *) {
            if let hdrImage = CIImage(data: imageData, options: [
                .applyOrientationProperty: true,
                .expandToHDR: true
            ]) {
                if let overlay = textOverlay {
                    hdrWithText = overlay.composited(over: hdrImage)
                } else {
                    hdrWithText = hdrImage
                }
            }
        }

        return saveAsHEIFData(sdrImage: sdrWithText, hdrImage: hdrWithText)
    }

    private static func createMonthlyTextOverlay(size: CGSize, shareData: MonthlyShareData, options: MonthExportOptions) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            drawMonthlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
        }

        return CIImage(image: textUIImage)
    }

    private static func drawMonthlyTextOverlay(width: CGFloat, height: CGFloat, shareData: MonthlyShareData, options: MonthExportOptions) {
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let lineHeight = baseFontSize * 1.4
        let padding = baseFontSize * 0.8

        let valueFont = UIFont.rounded(ofSize: baseFontSize, weight: .semibold)

        var yOffset = height - padding
        var lines: [(String, UIFont)] = []

        // 順番: 月の記録、合計距離、合計時間、合計回数、合計エネルギー、平均ペース、平均距離、平均時間
        // 下から上に描画するので逆順で追加
        if options.showAvgDuration {
            lines.append(("\(String(localized: "Avg Time")): \(shareData.averageDuration)", valueFont))
        }
        if options.showAvgDistance {
            lines.append(("\(String(localized: "Avg Distance")): \(shareData.averageDistance)", valueFont))
        }
        if options.showPace {
            lines.append(("\(String(localized: "Avg Pace")): \(shareData.averagePace)", valueFont))
        }
        if options.showCalories, let cal = shareData.totalCalories {
            lines.append(("\(String(localized: "Total Energy")): \(cal)", valueFont))
        }
        if options.showRunCount {
            lines.append(("\(String(localized: "Total Runs")): \(shareData.runCount)", valueFont))
        }
        if options.showDuration {
            lines.append(("\(String(localized: "Total Time")): \(shareData.totalDuration)", valueFont))
        }
        if options.showDistance {
            lines.append(("\(String(localized: "Total Distance")): \(shareData.totalDistance)", valueFont))
        }
        if options.showPeriod {
            lines.append((String(format: String(localized: "Records of %@", comment: "Month records label for share"), shareData.period), valueFont))
        }

        for (text, font) in lines {
            yOffset -= lineHeight
            let x = width - padding
            drawOutlinedText(text, at: CGPoint(x: x, y: yOffset), font: font)
        }
    }

    // MARK: - Yearly Stats Composition

    /// 年間統計画像を合成
    static func composeYearlyStats(imageData: Data, shareData: YearlyShareData, options: YearExportOptions) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createYearlyTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options)

        let sdrWithText: CIImage
        if let overlay = textOverlay {
            sdrWithText = overlay.composited(over: sdrImage)
        } else {
            sdrWithText = sdrImage
        }

        var hdrWithText: CIImage?
        if #available(iOS 17.0, *) {
            if let hdrImage = CIImage(data: imageData, options: [
                .applyOrientationProperty: true,
                .expandToHDR: true
            ]) {
                if let overlay = textOverlay {
                    hdrWithText = overlay.composited(over: hdrImage)
                } else {
                    hdrWithText = hdrImage
                }
            }
        }

        return saveAsHEIFData(sdrImage: sdrWithText, hdrImage: hdrWithText)
    }

    private static func createYearlyTextOverlay(size: CGSize, shareData: YearlyShareData, options: YearExportOptions) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            drawYearlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
        }

        return CIImage(image: textUIImage)
    }

    private static func drawYearlyTextOverlay(width: CGFloat, height: CGFloat, shareData: YearlyShareData, options: YearExportOptions) {
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let lineHeight = baseFontSize * 1.4
        let padding = baseFontSize * 0.8

        let valueFont = UIFont.rounded(ofSize: baseFontSize, weight: .semibold)

        var yOffset = height - padding
        var lines: [(String, UIFont)] = []

        // 順番: 年の記録、合計距離、合計時間、合計回数、合計エネルギー、平均ペース、平均距離、平均時間
        // 下から上に描画するので逆順で追加
        if options.showAvgDuration {
            lines.append(("\(String(localized: "Avg Time")): \(shareData.averageDuration)", valueFont))
        }
        if options.showAvgDistance {
            lines.append(("\(String(localized: "Avg Distance")): \(shareData.averageDistance)", valueFont))
        }
        if options.showPace {
            lines.append(("\(String(localized: "Avg Pace")): \(shareData.averagePace)", valueFont))
        }
        if options.showCalories, let cal = shareData.totalCalories {
            lines.append(("\(String(localized: "Total Energy")): \(cal)", valueFont))
        }
        if options.showRunCount {
            lines.append(("\(String(localized: "Total Runs")): \(shareData.runCount)", valueFont))
        }
        if options.showDuration {
            lines.append(("\(String(localized: "Total Time")): \(shareData.totalDuration)", valueFont))
        }
        if options.showDistance {
            lines.append(("\(String(localized: "Total Distance")): \(shareData.totalDistance)", valueFont))
        }
        if options.showYear {
            lines.append((String(format: String(localized: "%@ Records", comment: "Year records label for share"), shareData.year), valueFont))
        }

        for (text, font) in lines {
            yOffset -= lineHeight
            let x = width - padding
            drawOutlinedText(text, at: CGPoint(x: x, y: yOffset), font: font)
        }
    }

    // MARK: - Profile Stats Composition

    /// プロフィール統計画像を合成
    static func composeProfileStats(imageData: Data, shareData: ProfileShareData, options: ProfileExportOptions) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createProfileTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options)

        let sdrWithText: CIImage
        if let overlay = textOverlay {
            sdrWithText = overlay.composited(over: sdrImage)
        } else {
            sdrWithText = sdrImage
        }

        var hdrWithText: CIImage?
        if #available(iOS 17.0, *) {
            if let hdrImage = CIImage(data: imageData, options: [
                .applyOrientationProperty: true,
                .expandToHDR: true
            ]) {
                if let overlay = textOverlay {
                    hdrWithText = overlay.composited(over: hdrImage)
                } else {
                    hdrWithText = hdrImage
                }
            }
        }

        return saveAsHEIFData(sdrImage: sdrWithText, hdrImage: hdrWithText)
    }

    private static func createProfileTextOverlay(size: CGSize, shareData: ProfileShareData, options: ProfileExportOptions) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            drawProfileTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
        }

        return CIImage(image: textUIImage)
    }

    private static func drawProfileTextOverlay(width: CGFloat, height: CGFloat, shareData: ProfileShareData, options: ProfileExportOptions) {
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let lineHeight = baseFontSize * 1.4
        let padding = baseFontSize * 0.8

        let valueFont = UIFont.rounded(ofSize: baseFontSize, weight: .semibold)

        var yOffset = height - padding
        var lines: [(String, UIFont)] = []

        // 順番: 合計距離、合計時間、合計回数、合計エネルギー、平均ペース、平均距離、平均時間
        // 下から上に描画するので逆順で追加
        if options.showAvgDuration {
            lines.append(("\(String(localized: "Avg Time")): \(shareData.averageDuration)", valueFont))
        }
        if options.showAvgDistance {
            lines.append(("\(String(localized: "Avg Distance")): \(shareData.averageDistance)", valueFont))
        }
        if options.showPace {
            lines.append(("\(String(localized: "Avg Pace")): \(shareData.averagePace)", valueFont))
        }
        if options.showCalories, let cal = shareData.totalCalories {
            lines.append(("\(String(localized: "Total Energy")): \(cal)", valueFont))
        }
        if options.showRunCount {
            lines.append(("\(String(localized: "Total Runs")): \(shareData.runCount)", valueFont))
        }
        if options.showDuration {
            lines.append(("\(String(localized: "Total Time")): \(shareData.totalDuration)", valueFont))
        }
        if options.showDistance {
            lines.append(("\(String(localized: "Total Distance")): \(shareData.totalDistance)", valueFont))
        }

        for (text, font) in lines {
            yOffset -= lineHeight
            let x = width - padding
            drawOutlinedText(text, at: CGPoint(x: x, y: yOffset), font: font)
        }
    }
}

// MARK: - HDR Image View

struct HDRImageView: UIViewRepresentable {
    let imageData: Data

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.preferredImageDynamicRange = .high
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        imageView.tag = 100
        return containerView
    }

    func updateUIView(_ containerView: UIView, context: Context) {
        if let imageView = containerView.viewWithTag(100) as? UIImageView {
            imageView.image = loadHDRImage(from: imageData)
        }
    }

    private func loadHDRImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        // iOS 17+: HDRデコードを要求
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: true,
            kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR
        ]
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - UIFont Extension for Rounded Design

extension UIFont {
    static func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return systemFont
    }
}
