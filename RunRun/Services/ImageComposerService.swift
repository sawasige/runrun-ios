import SwiftUI
import CoreImage
import UIKit
import CoreLocation

// MARK: - Image Aspect Ratio

enum ImageAspectRatio: String, CaseIterable {
    case square = "1:1"      // 1080x1080
    case portrait = "4:5"    // 1080x1350
    case story = "9:16"      // 1080x1920

    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .story: return CGSize(width: 1080, height: 1920)
        }
    }
}

// MARK: - Image Composer (WWDC 2024 Strategy B - HDR対応)

enum ImageComposer {
    /// グラデーション背景画像をHEIF Dataとして生成
    /// - Parameter aspectRatio: 出力する画像のアスペクト比
    /// - Returns: HEIF形式の画像Data
    static func createGradientImageData(aspectRatio: ImageAspectRatio) -> Data? {
        let size = aspectRatio.size

        // Display P3 カラースペースでレンダリング
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let gradientImage = renderer.image { ctx in
            let context = ctx.cgContext

            // グラデーション色（Display P3）
            // 開始色: アクセントカラーの暗い版 (0.55, 0.18, 0.16)
            // 終了色: アクセントカラー (0.92, 0.30, 0.27)
            let colors = [
                CGColor(colorSpace: colorSpace, components: [0.55, 0.18, 0.16, 1.0])!,
                CGColor(colorSpace: colorSpace, components: [0.92, 0.30, 0.27, 1.0])!
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: locations
            ) else { return }

            // 上から下へグラデーション
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }

        // HEIF形式でエンコード
        guard let cgImage = gradientImage.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let ciContext = CIContext()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            try ciContext.writeHEIFRepresentation(
                of: ciImage,
                to: tempURL,
                format: .RGB10,
                colorSpace: colorSpace,
                options: [:]
            )
            return try Data(contentsOf: tempURL)
        } catch {
            print("Failed to create gradient HEIF: \(error)")
            return nil
        }
    }

    /// HDR Gainmapを保持したまま画像を合成してHEIF Dataを返す (WWDC 2024 Strategy A)
    /// - SDRとHDRの両方に同じテキストを描画
    /// - 両者の対応関係を維持してGain Mapを再計算
    /// - PHPhotoLibraryに直接渡すためにDataを返す
    /// - centered: グラデーション背景用の中央レイアウトを使用する場合はtrue
    static func composeAsHEIF(imageData: Data, record: RunningRecord, options: ExportOptions, routeCoordinates: [CLLocationCoordinate2D] = [], centered: Bool = false) async -> Data? {
        // 1. SDR画像を読み込み（向き自動適用）
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        // 2. ルート描画領域の明るさを計算
        let routeAreaBrightness: CGFloat?
        if options.showRoute && routeCoordinates.count >= 2 {
            routeAreaBrightness = calculateRouteAreaBrightness(image: sdrImage, routeCoordinates: routeCoordinates)
        } else {
            routeAreaBrightness = nil
        }

        // 3. テキストオーバーレイ画像を作成（一度だけ）
        let textOverlay = createTextOverlay(size: sdrImage.extent.size, record: record, options: options, routeCoordinates: routeCoordinates, routeAreaBrightness: routeAreaBrightness, centered: centered)

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
    private static func createTextOverlay(size: CGSize, record: RunningRecord, options: ExportOptions, routeCoordinates: [CLLocationCoordinate2D] = [], routeAreaBrightness: CGFloat? = nil, centered: Bool = false) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            if centered {
                drawCenteredTextOverlay(width: size.width, height: size.height, record: record, options: options, routeCoordinates: routeCoordinates)
            } else {
                drawTextOverlay(width: size.width, height: size.height, record: record, options: options, routeCoordinates: routeCoordinates, routeAreaBrightness: routeAreaBrightness)
            }
        }

        // premultiplied alphaを正しく処理するためCGImageから作成
        guard let cgImage = textUIImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage, options: [.applyOrientationProperty: true])
    }

    /// ルート描画領域の平均明るさを計算（0.0〜1.0）
    private static func calculateRouteAreaBrightness(image: CIImage, routeCoordinates: [CLLocationCoordinate2D]) -> CGFloat {
        let size = image.extent.size
        let overlayHeight = size.height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let padding = baseFontSize * 0.8
        let routeHeight = baseFontSize * 3.6  // drawTextOverlayと同じサイズ
        let routeWidth = routeHeight * 1.5

        // ルート描画領域を計算（右下に配置）
        let routeRect = CGRect(
            x: size.width - padding - routeWidth,
            y: size.height - padding - baseFontSize * 10 - routeHeight,  // テキストの上
            width: routeWidth,
            height: routeHeight
        )

        // CIImageの座標系はY軸が反転しているので調整
        let ciRect = CGRect(
            x: routeRect.minX,
            y: size.height - routeRect.maxY,
            width: routeRect.width,
            height: routeRect.height
        ).intersection(image.extent)

        guard !ciRect.isEmpty else { return 0.5 }

        // 領域を切り出して平均色を計算
        let croppedImage = image.cropped(to: ciRect)
        let context = CIContext()

        // CIAreaAverageフィルタで平均色を取得
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        avgFilter.setValue(croppedImage, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: croppedImage.extent), forKey: kCIInputExtentKey)

        guard let outputImage = avgFilter.outputImage else { return 0.5 }

        // 1x1ピクセルのビットマップとして取得
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // 輝度を計算（ITU-R BT.709）
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b

        return brightness
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
    private static func drawTextOverlay(width: CGFloat, height: CGFloat, record: RunningRecord, options: ExportOptions, routeCoordinates: [CLLocationCoordinate2D] = [], routeAreaBrightness: CGFloat? = nil) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
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
                subItems.append(record.formattedPace(useMetric: useMetric))
            }
            let subText = subItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.5
            drawOutlinedText(subText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 5. 距離（ヒーロー表示: 数値と単位を分離）
        if options.showDistance {
            // 単位
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(UnitFormatter.distanceUnit(useMetric: useMetric), at: CGPoint(x: x, y: yOffset), font: unitFont)

            // 数値（大きく）
            let distanceValue = UnitFormatter.formatDistanceValue(record.distanceInKilometers, useMetric: useMetric, decimals: 2)
            yOffset -= baseFontSize * 1.6
            drawOutlinedText(distanceValue, at: CGPoint(x: x, y: yOffset), font: heroFont)
        }

        // 6. ルート（テキストの上に描画）
        if options.showRoute && routeCoordinates.count >= 2 {
            yOffset -= baseFontSize * 0.5  // スペース
            let routeHeight = baseFontSize * 3.6  // 1.2倍に拡大
            let routeWidth = routeHeight * 1.5  // 横長のアスペクト比
            let routeRect = CGRect(x: x - routeWidth, y: yOffset - routeHeight, width: routeWidth, height: routeHeight)
            drawRoute(coordinates: routeCoordinates, in: routeRect, backgroundBrightness: routeAreaBrightness ?? 0.5)
        }
    }

    /// テキストオーバーレイを描画（中央レイアウト - グラデーション背景用）
    private static func drawCenteredTextOverlay(width: CGFloat, height: CGFloat, record: RunningRecord, options: ExportOptions, routeCoordinates: [CLLocationCoordinate2D] = []) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let centerX = width / 2
        let padding = min(width, height) * 0.05  // 上下の余白

        // 利用可能な高さ
        let availableHeight = height - padding * 2

        // 基本サイズ（後でスケール調整）
        let initialBaseSize = min(width, height) / 8.0

        // ルート表示フラグ
        let showRoute = options.showRoute && routeCoordinates.count >= 2

        // コンテンツの相対的なサイズ比率を定義
        struct ContentRatios {
            let routeHeight: CGFloat      // 3.0
            let routeSpacing: CGFloat     // 0.5
            let heroFontSize: CGFloat     // 1.8
            let unitFontSize: CGFloat     // 0.5
            let unitSpacing: CGFloat      // 0.1
            let subFontSize: CGFloat      // 0.45
            let subSpacing: CGFloat       // 0.5
            let metaFontSize: CGFloat     // 0.35
            let metaSpacing: CGFloat      // 0.3
            let logoHeight: CGFloat       // 0.8
            let logoSpacing: CGFloat      // 0.6
        }
        let ratios = ContentRatios(
            routeHeight: 3.0, routeSpacing: 0.5,
            heroFontSize: 1.8, unitFontSize: 0.5, unitSpacing: 0.1,
            subFontSize: 0.45, subSpacing: 0.5,
            metaFontSize: 0.35, metaSpacing: 0.3,
            logoHeight: 0.8, logoSpacing: 0.6
        )

        // 描画するテキスト要素を収集（相対比率で）
        var textElements: [(text: String, fontRatio: CGFloat, spacingRatio: CGFloat)] = []

        // 距離（ヒーロー表示）
        if options.showDistance {
            let distanceValue = UnitFormatter.formatDistanceValue(record.distanceInKilometers, useMetric: useMetric, decimals: 2)
            textElements.append((distanceValue, ratios.heroFontSize, 0))
            textElements.append((UnitFormatter.distanceUnit(useMetric: useMetric), ratios.unitFontSize, ratios.unitSpacing))
        }

        // 時間・ペース
        var subItems: [String] = []
        if options.showDuration { subItems.append(record.formattedDuration) }
        if options.showPace { subItems.append(record.formattedPace(useMetric: useMetric)) }
        if !subItems.isEmpty {
            textElements.append((subItems.joined(separator: "  "), ratios.subFontSize, ratios.subSpacing))
        }

        // 日付と時間
        var dateTimeItems: [String] = []
        if options.showDate {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            dateTimeItems.append(formatter.string(from: record.date))
        }
        if options.showStartTime {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            dateTimeItems.append(formatter.string(from: record.date))
        }
        if !dateTimeItems.isEmpty {
            textElements.append((dateTimeItems.joined(separator: " · "), ratios.metaFontSize, ratios.metaSpacing))
        }

        // 追加情報（カロリー、心拍、歩数）
        var metaItems: [String] = []
        if options.showCalories, let cal = record.formattedCalories { metaItems.append(cal) }
        if options.showHeartRate, let hr = record.formattedAverageHeartRate { metaItems.append(hr) }
        if options.showSteps, let steps = record.formattedStepCount { metaItems.append(steps) }
        if !metaItems.isEmpty {
            textElements.append((metaItems.joined(separator: "  "), ratios.metaFontSize, ratios.metaSpacing * 0.7))
        }

        // 全体の高さを計算（initialBaseSizeベース）
        func calculateTotalHeight(baseSize: CGFloat) -> CGFloat {
            var total: CGFloat = 0

            // ルート
            if showRoute {
                total += baseSize * ratios.routeHeight + baseSize * ratios.routeSpacing
            }

            // テキスト要素
            for (i, element) in textElements.enumerated() {
                let font = UIFont.rounded(ofSize: baseSize * element.fontRatio, weight: .bold)
                let textSize = (element.text as NSString).size(withAttributes: [.font: font])
                total += textSize.height
                if i > 0 {
                    total += baseSize * element.spacingRatio
                }
            }

            // ロゴ
            total += baseSize * ratios.logoSpacing + baseSize * ratios.logoHeight

            return total
        }

        // スケール係数を計算
        let initialTotal = calculateTotalHeight(baseSize: initialBaseSize)
        let scale = min(1.0, availableHeight / initialTotal)
        let baseSize = initialBaseSize * scale

        // 最終的な高さ
        let totalHeight = calculateTotalHeight(baseSize: baseSize)

        // 開始Y座標（中央揃え）
        var yOffset = (height - totalHeight) / 2

        // ルートを描画
        if showRoute {
            let routeH = baseSize * ratios.routeHeight
            let routeW = routeH * 1.5
            let routeRect = CGRect(x: centerX - routeW / 2, y: yOffset, width: routeW, height: routeH)
            drawRoute(coordinates: routeCoordinates, in: routeRect, backgroundBrightness: 0.3)
            yOffset += routeH + baseSize * ratios.routeSpacing
        }

        // テキスト要素を描画
        for (i, element) in textElements.enumerated() {
            if i > 0 {
                yOffset += baseSize * element.spacingRatio
            }
            let font = UIFont.rounded(ofSize: baseSize * element.fontRatio, weight: i == 0 ? .bold : (i == 1 ? .medium : .semibold))
            drawCenteredOutlinedText(element.text, centerX: centerX, y: yOffset, font: font)
            let textSize = (element.text as NSString).size(withAttributes: [.font: font])
            yOffset += textSize.height
        }

        // ロゴを描画
        let logoH = baseSize * ratios.logoHeight
        yOffset += baseSize * ratios.logoSpacing
        if let logo = UIImage(named: "Logo") {
            let logoAspect = logo.size.width / logo.size.height
            let logoWidth = logoH * logoAspect
            let logoRect = CGRect(x: centerX - logoWidth / 2, y: yOffset, width: logoWidth, height: logoH)

            // 少し小さめの角丸にクリップ
            let inset = logoH * 0.06
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
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
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

            UIGraphicsGetCurrentContext()?.restoreGState()
        }
    }

    /// 中央揃えでアウトライン付きテキストを描画
    private static func drawCenteredOutlinedText(_ text: String, centerX: CGFloat, y: CGFloat, font: UIFont) {
        let strokeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let hdrWhite = CGColor(colorSpace: colorSpace, components: [2.0, 2.0, 2.0, 1.0])!
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(cgColor: hdrWhite)
        ]

        let textSize = (text as NSString).size(withAttributes: fillAttributes)
        let drawPoint = CGPoint(x: centerX - textSize.width / 2, y: y)

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

    /// ルートを描画（背景の明るさに応じてアウトライン色を調整）
    private static func drawRoute(coordinates: [CLLocationCoordinate2D], in rect: CGRect, backgroundBrightness: CGFloat) {
        guard coordinates.count >= 2 else { return }

        // 座標のバウンディングボックスを計算
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon

        // 範囲が0の場合は描画しない
        guard latRange > 0 || lonRange > 0 else { return }

        // アスペクト比を維持してスケール
        let effectiveLatRange = max(latRange, 0.0001)
        let effectiveLonRange = max(lonRange, 0.0001)

        let scaleX = rect.width / CGFloat(effectiveLonRange)
        let scaleY = rect.height / CGFloat(effectiveLatRange)
        let scale = min(scaleX, scaleY) * 0.9  // 90%に縮小してマージンを確保

        // 中心を計算
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        // 座標を画像座標に変換する関数
        func toImagePoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let x = rect.midX + CGFloat(coord.longitude - centerLon) * scale
            // 緯度は上下反転（画像座標系は上が0）
            let y = rect.midY - CGFloat(coord.latitude - centerLat) * scale
            return CGPoint(x: x, y: y)
        }

        // パスを作成
        let path = UIBezierPath()
        let firstPoint = toImagePoint(coordinates[0])
        path.move(to: firstPoint)

        for coord in coordinates.dropFirst() {
            path.addLine(to: toImagePoint(coord))
        }

        // 線の太さを設定（rect高さの4%程度）
        let lineWidth = rect.height * 0.04

        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!

        // 背景の明るさに応じてアウトライン色を決定（背景に馴染む色）
        let outlineColor: UIColor
        if backgroundBrightness > 0.5 {
            // 明るい背景 → 白のアウトライン
            let hdrWhite = CGColor(colorSpace: colorSpace, components: [2.0, 2.0, 2.0, 1.0])!
            outlineColor = UIColor(cgColor: hdrWhite)
        } else {
            // 暗い背景 → 黒のアウトライン
            outlineColor = UIColor.black
        }

        // アウトラインを描画
        outlineColor.setStroke()
        path.lineWidth = lineWidth * 1.4
        path.stroke()

        // アクセントカラーの線（最内層）
        // Display P3 (0.921, 0.296, 0.274) をガンマ→線形変換 (^2.2) してから輝度2倍
        let hdrAccent = CGColor(colorSpace: colorSpace, components: [1.67, 0.14, 0.12, 1.0])!
        UIColor(cgColor: hdrAccent).setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    /// 累積距離グラフを描画
    private static func drawCumulativeChart(data: [(day: Int, distance: Double)], in rect: CGRect) {
        guard data.count >= 2 else { return }

        // データの範囲を計算
        let maxDay = data.map { $0.day }.max() ?? 31
        let maxDistance = data.map { $0.distance }.max() ?? 1.0

        guard maxDistance > 0 else { return }

        // パディングを追加
        let padding = rect.height * 0.08
        let chartRect = rect.insetBy(dx: padding, dy: padding)

        // 線の太さ
        let lineWidth = rect.height * 0.03

        // 座標変換関数
        func toPoint(_ day: Int, _ distance: Double) -> CGPoint {
            let x = chartRect.minX + (CGFloat(day - 1) / CGFloat(maxDay - 1)) * chartRect.width
            // Y軸は上下反転（画像座標系は上が0）
            let y = chartRect.maxY - (CGFloat(distance) / CGFloat(maxDistance)) * chartRect.height
            return CGPoint(x: x, y: y)
        }

        // エリアパスを作成（塗りつぶし用）- 線の太さ分左右・下に広げる
        let areaPath = UIBezierPath()
        let firstPoint = toPoint(data[0].day, data[0].distance)
        let lineOffset = lineWidth * 0.7  // アウトライン分も考慮
        let bottomY = chartRect.maxY + lineOffset

        // 左端を線の太さ分広げる
        areaPath.move(to: CGPoint(x: firstPoint.x - lineOffset, y: bottomY))
        areaPath.addLine(to: CGPoint(x: firstPoint.x - lineOffset, y: firstPoint.y))
        areaPath.addLine(to: firstPoint)

        for datum in data.dropFirst() {
            areaPath.addLine(to: toPoint(datum.day, datum.distance))
        }

        // 右端を線の太さ分広げる
        let lastPoint = toPoint(data.last!.day, data.last!.distance)
        areaPath.addLine(to: CGPoint(x: lastPoint.x + lineOffset, y: lastPoint.y))
        areaPath.addLine(to: CGPoint(x: lastPoint.x + lineOffset, y: bottomY))
        areaPath.close()

        // ラインパスを作成
        let linePath = UIBezierPath()
        linePath.move(to: firstPoint)
        for datum in data.dropFirst() {
            linePath.addLine(to: toPoint(datum.day, datum.distance))
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!

        // エリアを半透明で塗りつぶし
        let fillColor = CGColor(colorSpace: colorSpace, components: [1.67, 0.14, 0.12, 0.3])!
        UIColor(cgColor: fillColor).setFill()
        areaPath.fill()

        // アウトラインを描画（黒）
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        UIColor.black.setStroke()
        linePath.lineWidth = lineWidth * 1.4
        linePath.stroke()

        // メインの線を描画（HDRアクセントカラー）
        let hdrAccent = CGColor(colorSpace: colorSpace, components: [1.67, 0.14, 0.12, 1.0])!
        UIColor(cgColor: hdrAccent).setStroke()
        linePath.lineWidth = lineWidth
        linePath.stroke()
    }

    /// 月別距離バーグラフを描画
    private static func drawMonthlyBarChart(data: [(month: Int, distance: Double)], in rect: CGRect) {
        guard !data.isEmpty else { return }

        let maxDistance = data.map { $0.distance }.max() ?? 1.0
        guard maxDistance > 0 else { return }

        // パディングを追加
        let padding = rect.height * 0.08
        let chartRect = rect.insetBy(dx: padding, dy: padding)

        // 12本のバーを描画（線幅:線間 = 8:2）
        let barCount = 12
        let unitWidth = chartRect.width / CGFloat(barCount * 8 + (barCount - 1) * 2)
        let barWidth = unitWidth * 8
        let barSpacing = unitWidth * 2

        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let borderWidth = barWidth * 0.08

        // バーを描画
        for month in 1...barCount {
            let distance = data.first { $0.month == month }?.distance ?? 0
            let barHeight = CGFloat(distance / maxDistance) * chartRect.height
            let minBarHeight = barWidth * 0.3  // 最小高さ（データが0でも少し表示）

            let x = chartRect.minX + CGFloat(month - 1) * (barWidth + barSpacing)
            let actualHeight = max(barHeight, distance > 0 ? minBarHeight : 0)
            let y = chartRect.maxY - actualHeight

            if actualHeight > 0 {
                let barRect = CGRect(x: x, y: y, width: barWidth, height: actualHeight)
                let barPath = UIBezierPath(rect: barRect)

                // ボーダーを描画（黒）
                UIColor.black.setStroke()
                barPath.lineWidth = borderWidth
                barPath.stroke()

                // HDRアクセントカラーで塗りつぶし
                let hdrAccent = CGColor(colorSpace: colorSpace, components: [1.67, 0.14, 0.12, 1.0])!
                UIColor(cgColor: hdrAccent).setFill()
                barPath.fill()
            }
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
    static func composeMonthlyStats(imageData: Data, shareData: MonthlyShareData, options: MonthExportOptions, centered: Bool = false) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createMonthlyTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options, centered: centered)

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

    private static func createMonthlyTextOverlay(size: CGSize, shareData: MonthlyShareData, options: MonthExportOptions, centered: Bool = false) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            if centered {
                drawCenteredMonthlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            } else {
                drawMonthlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            }
        }

        return CIImage(image: textUIImage)
    }

    private static func drawMonthlyTextOverlay(width: CGFloat, height: CGFloat, shareData: MonthlyShareData, options: MonthExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let padding = baseFontSize * 0.8

        // フォントサイズのバリエーション（ラン詳細と同様）
        let heroFont = UIFont.rounded(ofSize: baseFontSize * 1.4, weight: .bold)      // 距離の数値
        let unitFont = UIFont.rounded(ofSize: baseFontSize * 0.8, weight: .medium)    // 単位
        let subFont = UIFont.rounded(ofSize: baseFontSize * 0.9, weight: .semibold)   // 時間・回数
        let metaFont = UIFont.rounded(ofSize: baseFontSize * 0.85, weight: .regular)  // 平均値・その他

        var yOffset = height - padding
        let x = width - padding

        // === 下から上に描画 ===

        // 1. アプリロゴ（画像・HDRコントラスト調整）
        let logoHeight = baseFontSize * 2.0
        if let logo = UIImage(named: "Logo") {
            let logoAspect = logo.size.width / logo.size.height
            let logoWidth = logoHeight * logoAspect
            let logoRect = CGRect(x: x - logoWidth, y: yOffset - logoHeight, width: logoWidth, height: logoHeight)

            let inset = logoHeight * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            let cornerRadius = clipRect.height * 0.22
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.saveGState()
                UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius).addClip()
            }

            if let ciLogo = CIImage(image: logo),
               let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
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

            UIGraphicsGetCurrentContext()?.restoreGState()
            yOffset -= logoHeight + baseFontSize * 0.3
        }

        // 2. 平均値（控えめに表示）
        var avgItems: [String] = []
        if options.showPace {
            avgItems.append(shareData.averagePace)
        }
        if options.showAvgDistance {
            avgItems.append(shareData.averageDistance)
        }
        if options.showAvgDuration {
            avgItems.append(shareData.averageDuration)
        }
        if !avgItems.isEmpty {
            let avgText = avgItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(avgText, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 3. カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(cal, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 4. 時間・回数（1行にまとめる）
        if options.showDuration || options.showRunCount {
            var subItems: [String] = []
            if options.showDuration {
                subItems.append(shareData.totalDuration)
            }
            if options.showRunCount {
                subItems.append(String(format: String(localized: "%d runs"), shareData.runCount))
            }
            let subText = subItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.5
            drawOutlinedText(subText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 5. 距離（ヒーロー表示: 数値と単位を分離）
        if options.showDistance {
            // 単位
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(UnitFormatter.distanceUnit(useMetric: useMetric), at: CGPoint(x: x, y: yOffset), font: unitFont)

            // 数値（大きく）- shareData.totalDistanceから数値部分を抽出
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            yOffset -= baseFontSize * 1.6
            drawOutlinedText(distanceValue, at: CGPoint(x: x, y: yOffset), font: heroFont)
        }

        // 6. 期間（一番上に表示）
        if options.showPeriod {
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(shareData.period, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 7. 累積距離グラフ（テキストの上に描画）
        if options.showProgressChart && !shareData.cumulativeData.isEmpty {
            yOffset -= baseFontSize * 0.5  // スペース
            let chartHeight = baseFontSize * 3.6  // ルートと同じサイズ
            let chartWidth = chartHeight * 1.5  // 横長のアスペクト比
            let chartRect = CGRect(x: x - chartWidth, y: yOffset - chartHeight, width: chartWidth, height: chartHeight)
            drawCumulativeChart(data: shareData.cumulativeData, in: chartRect)
        }
    }

    /// 月間統計テキストオーバーレイを描画（中央レイアウト）
    private static func drawCenteredMonthlyTextOverlay(width: CGFloat, height: CGFloat, shareData: MonthlyShareData, options: MonthExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let centerX = width / 2
        let padding = min(width, height) * 0.05

        let availableHeight = height - padding * 2
        let initialBaseSize = min(width, height) / 8.0

        // グラフ表示フラグ
        let showChart = options.showProgressChart && !shareData.cumulativeData.isEmpty

        // コンテンツ比率
        struct Ratios {
            let chartHeight: CGFloat = 2.5
            let chartSpacing: CGFloat = 0.5
            let heroFontSize: CGFloat = 1.8
            let unitFontSize: CGFloat = 0.5
            let unitSpacing: CGFloat = 0.1
            let subFontSize: CGFloat = 0.45
            let subSpacing: CGFloat = 0.5
            let metaFontSize: CGFloat = 0.35
            let metaSpacing: CGFloat = 0.3
            let logoHeight: CGFloat = 0.8
            let logoSpacing: CGFloat = 0.6
        }
        let ratios = Ratios()

        // テキスト要素を収集
        var textElements: [(text: String, fontRatio: CGFloat, spacingRatio: CGFloat, weight: UIFont.Weight)] = []

        // 期間
        if options.showPeriod {
            textElements.append((shareData.period, ratios.subFontSize, 0, .semibold))
        }

        // 距離
        if options.showDistance {
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            textElements.append((distanceValue, ratios.heroFontSize, ratios.subSpacing, .bold))
            textElements.append((UnitFormatter.distanceUnit(useMetric: useMetric), ratios.unitFontSize, ratios.unitSpacing, .medium))
        }

        // 時間・回数
        var subItems: [String] = []
        if options.showDuration { subItems.append(shareData.totalDuration) }
        if options.showRunCount { subItems.append(String(format: String(localized: "%d runs"), shareData.runCount)) }
        if !subItems.isEmpty {
            textElements.append((subItems.joined(separator: "  "), ratios.subFontSize, ratios.subSpacing, .semibold))
        }

        // カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            textElements.append((cal, ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        // 平均値
        var avgItems: [String] = []
        if options.showPace { avgItems.append(shareData.averagePace) }
        if options.showAvgDistance { avgItems.append(shareData.averageDistance) }
        if options.showAvgDuration { avgItems.append(shareData.averageDuration) }
        if !avgItems.isEmpty {
            textElements.append((avgItems.joined(separator: "  "), ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        // 高さ計算
        func calcHeight(baseSize: CGFloat) -> CGFloat {
            var total: CGFloat = 0
            if showChart { total += baseSize * ratios.chartHeight + baseSize * ratios.chartSpacing }
            for (i, el) in textElements.enumerated() {
                let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
                let size = (el.text as NSString).size(withAttributes: [.font: font])
                total += size.height
                if i > 0 { total += baseSize * el.spacingRatio }
            }
            total += baseSize * ratios.logoSpacing + baseSize * ratios.logoHeight
            return total
        }

        let scale = min(1.0, availableHeight / calcHeight(baseSize: initialBaseSize))
        let baseSize = initialBaseSize * scale
        let totalHeight = calcHeight(baseSize: baseSize)

        var yOffset = (height - totalHeight) / 2

        // グラフ描画
        if showChart {
            let chartH = baseSize * ratios.chartHeight
            let chartW = chartH * 1.5
            let chartRect = CGRect(x: centerX - chartW / 2, y: yOffset, width: chartW, height: chartH)
            drawCumulativeChart(data: shareData.cumulativeData, in: chartRect)
            yOffset += chartH + baseSize * ratios.chartSpacing
        }

        // テキスト描画
        for (i, el) in textElements.enumerated() {
            if i > 0 { yOffset += baseSize * el.spacingRatio }
            let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
            drawCenteredOutlinedText(el.text, centerX: centerX, y: yOffset, font: font)
            let size = (el.text as NSString).size(withAttributes: [.font: font])
            yOffset += size.height
        }

        // ロゴ描画
        let logoH = baseSize * ratios.logoHeight
        yOffset += baseSize * ratios.logoSpacing
        if let logo = UIImage(named: "Logo") {
            let logoW = logoH * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: centerX - logoW / 2, y: yOffset, width: logoW, height: logoH)
            let inset = logoH * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(roundedRect: clipRect, cornerRadius: clipRect.height * 0.22).addClip()
            if let ciLogo = CIImage(image: logo), let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
                if let output = filter.outputImage,
                   let cgImage = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!]).createCGImage(output, from: output.extent) {
                    UIImage(cgImage: cgImage).draw(in: logoRect)
                } else { logo.draw(in: logoRect) }
            } else { logo.draw(in: logoRect) }
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
    }

    // MARK: - Yearly Stats Composition

    /// 年間統計画像を合成
    static func composeYearlyStats(imageData: Data, shareData: YearlyShareData, options: YearExportOptions, centered: Bool = false) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createYearlyTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options, centered: centered)

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

    private static func createYearlyTextOverlay(size: CGSize, shareData: YearlyShareData, options: YearExportOptions, centered: Bool = false) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            if centered {
                drawCenteredYearlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            } else {
                drawYearlyTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            }
        }

        return CIImage(image: textUIImage)
    }

    private static func drawYearlyTextOverlay(width: CGFloat, height: CGFloat, shareData: YearlyShareData, options: YearExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let padding = baseFontSize * 0.8

        // フォントサイズのバリエーション（月詳細と同様）
        let heroFont = UIFont.rounded(ofSize: baseFontSize * 1.4, weight: .bold)
        let unitFont = UIFont.rounded(ofSize: baseFontSize * 0.8, weight: .medium)
        let subFont = UIFont.rounded(ofSize: baseFontSize * 0.9, weight: .semibold)
        let metaFont = UIFont.rounded(ofSize: baseFontSize * 0.85, weight: .regular)

        var yOffset = height - padding
        let x = width - padding

        // === 下から上に描画 ===

        // 1. アプリロゴ（画像・HDRコントラスト調整）
        let logoHeight = baseFontSize * 2.0
        if let logo = UIImage(named: "Logo") {
            let logoAspect = logo.size.width / logo.size.height
            let logoWidth = logoHeight * logoAspect
            let logoRect = CGRect(x: x - logoWidth, y: yOffset - logoHeight, width: logoWidth, height: logoHeight)

            let inset = logoHeight * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            let cornerRadius = clipRect.height * 0.22
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.saveGState()
                UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius).addClip()
            }

            if let ciLogo = CIImage(image: logo),
               let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
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

            UIGraphicsGetCurrentContext()?.restoreGState()
            yOffset -= logoHeight + baseFontSize * 0.3
        }

        // 2. 平均値（控えめに表示）
        var avgItems: [String] = []
        if options.showPace {
            avgItems.append(shareData.averagePace)
        }
        if options.showAvgDistance {
            avgItems.append(shareData.averageDistance)
        }
        if options.showAvgDuration {
            avgItems.append(shareData.averageDuration)
        }
        if !avgItems.isEmpty {
            let avgText = avgItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(avgText, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 3. カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(cal, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 4. 時間・回数（1行にまとめる）
        if options.showDuration || options.showRunCount {
            var subItems: [String] = []
            if options.showDuration {
                subItems.append(shareData.totalDuration)
            }
            if options.showRunCount {
                subItems.append(String(format: String(localized: "%d runs"), shareData.runCount))
            }
            let subText = subItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.5
            drawOutlinedText(subText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 5. 距離（ヒーロー表示: 数値と単位を分離）
        if options.showDistance {
            // 単位
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(UnitFormatter.distanceUnit(useMetric: useMetric), at: CGPoint(x: x, y: yOffset), font: unitFont)

            // 数値（大きく）
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            yOffset -= baseFontSize * 1.6
            drawOutlinedText(distanceValue, at: CGPoint(x: x, y: yOffset), font: heroFont)
        }

        // 6. 年（一番上に表示）
        if options.showYear {
            let yearText = String(format: String(localized: "%@ Records", comment: "Year records label for share"), shareData.year)
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(yearText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 7. 月別距離グラフ（テキストの上に描画）
        if options.showMonthlyChart && !shareData.monthlyDistanceData.isEmpty {
            yOffset -= baseFontSize * 0.5  // スペース
            let chartHeight = baseFontSize * 3.6  // ルートと同じサイズ
            let chartWidth = chartHeight * 1.5  // 横長のアスペクト比
            let chartRect = CGRect(x: x - chartWidth, y: yOffset - chartHeight, width: chartWidth, height: chartHeight)
            drawMonthlyBarChart(data: shareData.monthlyDistanceData, in: chartRect)
        }
    }

    /// 年間統計テキストオーバーレイを描画（中央レイアウト）
    private static func drawCenteredYearlyTextOverlay(width: CGFloat, height: CGFloat, shareData: YearlyShareData, options: YearExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let centerX = width / 2
        let padding = min(width, height) * 0.05

        let availableHeight = height - padding * 2
        let initialBaseSize = min(width, height) / 8.0

        let showChart = options.showMonthlyChart && !shareData.monthlyDistanceData.isEmpty

        struct Ratios {
            let chartHeight: CGFloat = 2.5
            let chartSpacing: CGFloat = 0.5
            let heroFontSize: CGFloat = 1.8
            let unitFontSize: CGFloat = 0.5
            let unitSpacing: CGFloat = 0.1
            let subFontSize: CGFloat = 0.45
            let subSpacing: CGFloat = 0.5
            let metaFontSize: CGFloat = 0.35
            let metaSpacing: CGFloat = 0.3
            let logoHeight: CGFloat = 0.8
            let logoSpacing: CGFloat = 0.6
        }
        let ratios = Ratios()

        var textElements: [(text: String, fontRatio: CGFloat, spacingRatio: CGFloat, weight: UIFont.Weight)] = []

        // 年
        if options.showYear {
            let yearText = String(format: String(localized: "%@ Records", comment: "Year records label for share"), shareData.year)
            textElements.append((yearText, ratios.subFontSize, 0, .semibold))
        }

        // 距離
        if options.showDistance {
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            textElements.append((distanceValue, ratios.heroFontSize, ratios.subSpacing, .bold))
            textElements.append((UnitFormatter.distanceUnit(useMetric: useMetric), ratios.unitFontSize, ratios.unitSpacing, .medium))
        }

        // 時間・回数
        var subItems: [String] = []
        if options.showDuration { subItems.append(shareData.totalDuration) }
        if options.showRunCount { subItems.append(String(format: String(localized: "%d runs"), shareData.runCount)) }
        if !subItems.isEmpty {
            textElements.append((subItems.joined(separator: "  "), ratios.subFontSize, ratios.subSpacing, .semibold))
        }

        // カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            textElements.append((cal, ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        // 平均値
        var avgItems: [String] = []
        if options.showPace { avgItems.append(shareData.averagePace) }
        if options.showAvgDistance { avgItems.append(shareData.averageDistance) }
        if options.showAvgDuration { avgItems.append(shareData.averageDuration) }
        if !avgItems.isEmpty {
            textElements.append((avgItems.joined(separator: "  "), ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        func calcHeight(baseSize: CGFloat) -> CGFloat {
            var total: CGFloat = 0
            if showChart { total += baseSize * ratios.chartHeight + baseSize * ratios.chartSpacing }
            for (i, el) in textElements.enumerated() {
                let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
                let size = (el.text as NSString).size(withAttributes: [.font: font])
                total += size.height
                if i > 0 { total += baseSize * el.spacingRatio }
            }
            total += baseSize * ratios.logoSpacing + baseSize * ratios.logoHeight
            return total
        }

        let scale = min(1.0, availableHeight / calcHeight(baseSize: initialBaseSize))
        let baseSize = initialBaseSize * scale
        let totalHeight = calcHeight(baseSize: baseSize)

        var yOffset = (height - totalHeight) / 2

        // グラフ描画
        if showChart {
            let chartH = baseSize * ratios.chartHeight
            let chartW = chartH * 1.5
            let chartRect = CGRect(x: centerX - chartW / 2, y: yOffset, width: chartW, height: chartH)
            drawMonthlyBarChart(data: shareData.monthlyDistanceData, in: chartRect)
            yOffset += chartH + baseSize * ratios.chartSpacing
        }

        // テキスト描画
        for (i, el) in textElements.enumerated() {
            if i > 0 { yOffset += baseSize * el.spacingRatio }
            let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
            drawCenteredOutlinedText(el.text, centerX: centerX, y: yOffset, font: font)
            let size = (el.text as NSString).size(withAttributes: [.font: font])
            yOffset += size.height
        }

        // ロゴ描画
        let logoH = baseSize * ratios.logoHeight
        yOffset += baseSize * ratios.logoSpacing
        if let logo = UIImage(named: "Logo") {
            let logoW = logoH * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: centerX - logoW / 2, y: yOffset, width: logoW, height: logoH)
            let inset = logoH * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(roundedRect: clipRect, cornerRadius: clipRect.height * 0.22).addClip()
            if let ciLogo = CIImage(image: logo), let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
                if let output = filter.outputImage,
                   let cgImage = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!]).createCGImage(output, from: output.extent) {
                    UIImage(cgImage: cgImage).draw(in: logoRect)
                } else { logo.draw(in: logoRect) }
            } else { logo.draw(in: logoRect) }
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
    }

    // MARK: - Profile Stats Composition

    /// プロフィール統計画像を合成
    static func composeProfileStats(imageData: Data, shareData: ProfileShareData, options: ProfileExportOptions, centered: Bool = false) async -> Data? {
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        let textOverlay = createProfileTextOverlay(size: sdrImage.extent.size, shareData: shareData, options: options, centered: centered)

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

    private static func createProfileTextOverlay(size: CGSize, shareData: ProfileShareData, options: ProfileExportOptions, centered: Bool = false) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            if centered {
                drawCenteredProfileTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            } else {
                drawProfileTextOverlay(width: size.width, height: size.height, shareData: shareData, options: options)
            }
        }

        return CIImage(image: textUIImage)
    }

    private static func drawProfileTextOverlay(width: CGFloat, height: CGFloat, shareData: ProfileShareData, options: ProfileExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let padding = baseFontSize * 0.8

        // フォントサイズのバリエーション（月詳細・年詳細と同様）
        let heroFont = UIFont.rounded(ofSize: baseFontSize * 1.4, weight: .bold)
        let unitFont = UIFont.rounded(ofSize: baseFontSize * 0.8, weight: .medium)
        let subFont = UIFont.rounded(ofSize: baseFontSize * 0.9, weight: .semibold)
        let metaFont = UIFont.rounded(ofSize: baseFontSize * 0.85, weight: .regular)

        var yOffset = height - padding
        let x = width - padding

        // === 下から上に描画 ===

        // 1. アプリロゴ（画像・HDRコントラスト調整）
        let logoHeight = baseFontSize * 2.0
        if let logo = UIImage(named: "Logo") {
            let logoAspect = logo.size.width / logo.size.height
            let logoWidth = logoHeight * logoAspect
            let logoRect = CGRect(x: x - logoWidth, y: yOffset - logoHeight, width: logoWidth, height: logoHeight)

            let inset = logoHeight * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            let cornerRadius = clipRect.height * 0.22
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.saveGState()
                UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius).addClip()
            }

            if let ciLogo = CIImage(image: logo),
               let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
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

            UIGraphicsGetCurrentContext()?.restoreGState()
            yOffset -= logoHeight + baseFontSize * 0.3
        }

        // 2. 平均値（控えめに表示）
        var avgItems: [String] = []
        if options.showPace {
            avgItems.append(shareData.averagePace)
        }
        if options.showAvgDistance {
            avgItems.append(shareData.averageDistance)
        }
        if options.showAvgDuration {
            avgItems.append(shareData.averageDuration)
        }
        if !avgItems.isEmpty {
            let avgText = avgItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(avgText, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 3. カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            yOffset -= baseFontSize * 1.2
            drawOutlinedText(cal, at: CGPoint(x: x, y: yOffset), font: metaFont)
        }

        // 4. 時間・回数（1行にまとめる）
        if options.showDuration || options.showRunCount {
            var subItems: [String] = []
            if options.showDuration {
                subItems.append(shareData.totalDuration)
            }
            if options.showRunCount {
                subItems.append(String(format: String(localized: "%d runs"), shareData.runCount))
            }
            let subText = subItems.joined(separator: "  ")
            yOffset -= baseFontSize * 1.5
            drawOutlinedText(subText, at: CGPoint(x: x, y: yOffset), font: subFont)
        }

        // 5. 距離（ヒーロー表示: 数値と単位を分離）
        if options.showDistance {
            // 単位
            yOffset -= baseFontSize * 1.0
            drawOutlinedText(UnitFormatter.distanceUnit(useMetric: useMetric), at: CGPoint(x: x, y: yOffset), font: unitFont)

            // 数値（大きく）
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            yOffset -= baseFontSize * 1.6
            drawOutlinedText(distanceValue, at: CGPoint(x: x, y: yOffset), font: heroFont)
        }
    }

    /// プロフィール統計テキストオーバーレイを描画（中央レイアウト）
    private static func drawCenteredProfileTextOverlay(width: CGFloat, height: CGFloat, shareData: ProfileShareData, options: ProfileExportOptions) {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        let centerX = width / 2
        let padding = min(width, height) * 0.05

        let availableHeight = height - padding * 2
        let initialBaseSize = min(width, height) / 8.0

        struct Ratios {
            let heroFontSize: CGFloat = 1.8
            let unitFontSize: CGFloat = 0.5
            let unitSpacing: CGFloat = 0.1
            let subFontSize: CGFloat = 0.45
            let subSpacing: CGFloat = 0.5
            let metaFontSize: CGFloat = 0.35
            let metaSpacing: CGFloat = 0.3
            let logoHeight: CGFloat = 0.8
            let logoSpacing: CGFloat = 0.6
        }
        let ratios = Ratios()

        var textElements: [(text: String, fontRatio: CGFloat, spacingRatio: CGFloat, weight: UIFont.Weight)] = []

        // 距離
        if options.showDistance {
            let distanceValue = shareData.totalDistance
                .replacingOccurrences(of: UnitFormatter.distanceUnit(useMetric: useMetric), with: "")
                .trimmingCharacters(in: .whitespaces)
            textElements.append((distanceValue, ratios.heroFontSize, 0, .bold))
            textElements.append((UnitFormatter.distanceUnit(useMetric: useMetric), ratios.unitFontSize, ratios.unitSpacing, .medium))
        }

        // 時間・回数
        var subItems: [String] = []
        if options.showDuration { subItems.append(shareData.totalDuration) }
        if options.showRunCount { subItems.append(String(format: String(localized: "%d runs"), shareData.runCount)) }
        if !subItems.isEmpty {
            textElements.append((subItems.joined(separator: "  "), ratios.subFontSize, ratios.subSpacing, .semibold))
        }

        // カロリー
        if options.showCalories, let cal = shareData.totalCalories {
            textElements.append((cal, ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        // 平均値
        var avgItems: [String] = []
        if options.showPace { avgItems.append(shareData.averagePace) }
        if options.showAvgDistance { avgItems.append(shareData.averageDistance) }
        if options.showAvgDuration { avgItems.append(shareData.averageDuration) }
        if !avgItems.isEmpty {
            textElements.append((avgItems.joined(separator: "  "), ratios.metaFontSize, ratios.metaSpacing, .regular))
        }

        func calcHeight(baseSize: CGFloat) -> CGFloat {
            var total: CGFloat = 0
            for (i, el) in textElements.enumerated() {
                let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
                let size = (el.text as NSString).size(withAttributes: [.font: font])
                total += size.height
                if i > 0 { total += baseSize * el.spacingRatio }
            }
            total += baseSize * ratios.logoSpacing + baseSize * ratios.logoHeight
            return total
        }

        let scale = min(1.0, availableHeight / calcHeight(baseSize: initialBaseSize))
        let baseSize = initialBaseSize * scale
        let totalHeight = calcHeight(baseSize: baseSize)

        var yOffset = (height - totalHeight) / 2

        // テキスト描画
        for (i, el) in textElements.enumerated() {
            if i > 0 { yOffset += baseSize * el.spacingRatio }
            let font = UIFont.rounded(ofSize: baseSize * el.fontRatio, weight: el.weight)
            drawCenteredOutlinedText(el.text, centerX: centerX, y: yOffset, font: font)
            let size = (el.text as NSString).size(withAttributes: [.font: font])
            yOffset += size.height
        }

        // ロゴ描画
        let logoH = baseSize * ratios.logoHeight
        yOffset += baseSize * ratios.logoSpacing
        if let logo = UIImage(named: "Logo") {
            let logoW = logoH * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: centerX - logoW / 2, y: yOffset, width: logoW, height: logoH)
            let inset = logoH * 0.06
            let clipRect = logoRect.insetBy(dx: inset, dy: inset)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(roundedRect: clipRect, cornerRadius: clipRect.height * 0.22).addClip()
            if let ciLogo = CIImage(image: logo), let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciLogo, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.4, forKey: kCIInputSaturationKey)
                if let output = filter.outputImage,
                   let cgImage = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!]).createCGImage(output, from: output.extent) {
                    UIImage(cgImage: cgImage).draw(in: logoRect)
                } else { logo.draw(in: logoRect) }
            } else { logo.draw(in: logoRect) }
            UIGraphicsGetCurrentContext()?.restoreGState()
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
