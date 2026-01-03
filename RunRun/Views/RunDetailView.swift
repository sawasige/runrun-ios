import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import PhotosUI

struct RunDetailView: View {
    let record: RunningRecord
    var isOwnRecord: Bool = true

    @State private var routeLocations: [CLLocation] = []
    @State private var splits: [Split] = []
    @State private var isLoadingRoute = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showFullScreenMap = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showExportPreview = false
    @State private var exportImageData: Data?
    @Namespace private var mapAnimation

    private let healthKitService = HealthKitService()

    private var routeCoordinates: [CLLocationCoordinate2D] {
        routeLocations.map { $0.coordinate }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: record.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: record.date)
    }

    var body: some View {
        List {
            // 地図セクション
            if !routeCoordinates.isEmpty {
                Section {
                    mapPreview
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.4)) {
                                showFullScreenMap = true
                            }
                        }
                }
            } else if isLoadingRoute {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }

            // ヘッダーセクション
            Section {
                VStack(spacing: 16) {
                    Text(formattedDate)
                        .font(.headline)
                    Text(formattedTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 32) {
                        StatItem(value: record.formattedDistance, label: "距離")
                        StatItem(value: record.formattedDuration, label: "時間")
                        StatItem(value: record.formattedPace, label: "ペース")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // スプリットセクション
            if !splits.isEmpty {
                Section("スプリット") {
                    ForEach(splits) { split in
                        HStack {
                            Text(split.formattedKilometer)
                            Spacer()
                            Text(split.formattedPace)
                                .fontWeight(.medium)
                                .monospacedDigit()
                            Text("/km")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 心拍数セクション
            if record.averageHeartRate != nil || record.maxHeartRate != nil || record.minHeartRate != nil {
                Section("心拍数") {
                    if let avg = record.formattedAverageHeartRate {
                        LabeledContent("平均", value: avg)
                    }
                    if let max = record.formattedMaxHeartRate {
                        LabeledContent("最大", value: max)
                    }
                    if let min = record.formattedMinHeartRate {
                        LabeledContent("最小", value: min)
                    }
                }
            }

            // 効率セクション
            if record.cadence != nil || record.strideLength != nil || record.stepCount != nil {
                Section("効率") {
                    if let cadence = record.formattedCadence {
                        LabeledContent("ケイデンス", value: cadence)
                    }
                    if let stride = record.formattedStrideLength {
                        LabeledContent("ストライド", value: stride)
                    }
                    if let steps = record.formattedStepCount {
                        LabeledContent("歩数", value: steps)
                    }
                }
            }

            // エネルギーセクション
            if let calories = record.formattedCalories {
                Section("エネルギー") {
                    LabeledContent("消費カロリー", value: calories)
                }
            }
        }
        .navigationTitle("ランニング詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnRecord {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                await loadSelectedPhoto()
            }
        }
        .task {
            await loadRouteData()
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            FullScreenMapView(
                locations: routeLocations,
                kilometerPoints: calculateKilometerPoints()
            )
        }
        .fullScreenCover(isPresented: $showExportPreview) {
            if let imageData = exportImageData {
                RunExportPreviewView(
                    imageData: imageData,
                    record: record
                )
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let transferable = try await item.loadTransferable(type: TransferableImage.self) {
                await MainActor.run {
                    exportImageData = transferable.data
                    showExportPreview = true
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }

        // 選択をリセット（次回選択可能にする）
        selectedPhotoItem = nil
    }

    private var mapPreview: some View {
        Map(position: $mapCameraPosition) {
            MapPolyline(coordinates: routeCoordinates)
                .stroke(.blue, lineWidth: 4)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func loadRouteData() async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        // 該当日のワークアウトを検索
        guard let workout = await findWorkout(for: record.date) else { return }

        // ルートを取得
        let locations = await healthKitService.fetchWorkoutRoute(for: workout)
        guard !locations.isEmpty else { return }

        // ロケーション配列を保存
        routeLocations = locations

        // スプリットを計算
        splits = healthKitService.calculateSplits(from: locations)

        // カメラ位置を設定（ルート全体が表示されるように）
        if let region = regionToFitCoordinates(routeCoordinates) {
            mapCameraPosition = .region(region)
        }
    }

    /// 1kmごとの座標を計算
    private func calculateKilometerPoints() -> [KilometerPoint] {
        guard routeLocations.count >= 2 else { return [] }

        var points: [KilometerPoint] = []
        var currentKm = 1
        var accumulatedDistance: Double = 0

        for i in 1..<routeLocations.count {
            let distance = routeLocations[i].distance(from: routeLocations[i - 1])
            accumulatedDistance += distance

            if accumulatedDistance >= 1000 {
                points.append(KilometerPoint(
                    kilometer: currentKm,
                    coordinate: routeLocations[i].coordinate
                ))
                currentKm += 1
                accumulatedDistance = 0
            }
        }

        return points
    }

    /// 全座標を含む領域を計算
    private func regionToFitCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // 余白を追加（20%）
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2

        // 最小スパンを設定（ズームしすぎ防止）
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005),
            longitudeDelta: max(lonDelta, 0.005)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func findWorkout(for date: Date) async -> HKWorkout? {
        let calendar = Calendar.current

        do {
            let allWorkouts = try await healthKitService.fetchAllRawRunningWorkouts()
            return allWorkouts.first { workout in
                calendar.isDate(workout.startDate, inSameDayAs: date) &&
                abs(workout.startDate.timeIntervalSince(date)) < 60 // 1分以内
            }
        } catch {
            return nil
        }
    }
}

// MARK: - Run Export Preview View

import Photos

struct RunExportPreviewView: View {
    let imageData: Data
    let record: RunningRecord

    @Environment(\.dismiss) private var dismiss
    @State private var composedHEIFData: Data?
    @State private var previewImage: UIImage?
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = previewImage {
                    // TODO: HDRプレビュー対応（現在はSDR表示、保存はHDR）
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if isProcessing {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await saveToPhotos()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    .disabled(composedHEIFData == nil || isSaving)
                }
            }
            .task {
                await composeImage()
            }
            .alert("保存完了", isPresented: $showSaveSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("写真に保存しました")
            }
            .alert("エラー", isPresented: .init(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func composeImage() async {
        isProcessing = true

        let data = imageData
        let rec = record

        let result = await Task.detached(priority: .userInitiated) {
            await ImageComposer.composeAsHEIF(imageData: data, record: rec)
        }.value

        await MainActor.run {
            composedHEIFData = result
            if let heifData = result {
                previewImage = UIImage(data: heifData)
            }
            isProcessing = false
        }
    }

    private func saveToPhotos() async {
        guard let heifData = composedHEIFData else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            // 写真ライブラリへのアクセス許可を確認
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saveError = "写真へのアクセスが許可されていません"
                return
            }

            // HEIFデータを直接写真ライブラリに保存
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = "RunRun_\(Int(Date().timeIntervalSince1970)).heic"

                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: heifData, options: options)
            }

            showSaveSuccess = true
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Image Composer (WWDC 2024 Strategy B - HDR対応)

import CoreImage

enum ImageComposer {
    /// HDR Gainmapを保持したまま画像を合成してHEIF Dataを返す (WWDC 2024 Strategy A)
    /// - SDRとHDRの両方に同じテキストを描画
    /// - 両者の対応関係を維持してGain Mapを再計算
    /// - PHPhotoLibraryに直接渡すためにDataを返す
    static func composeAsHEIF(imageData: Data, record: RunningRecord) async -> Data? {
        // 1. SDR画像を読み込み（向き自動適用）
        guard let sdrImage = CIImage(data: imageData, options: [
            .applyOrientationProperty: true
        ]) else {
            return nil
        }

        // 2. テキストオーバーレイ画像を作成（一度だけ）
        let textOverlay = createTextOverlay(size: sdrImage.extent.size, record: record)

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
    private static func createTextOverlay(size: CGSize, record: RunningRecord) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let textUIImage = renderer.image { _ in
            drawTextOverlay(width: size.width, height: size.height, record: record)
        }

        return CIImage(image: textUIImage)
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

    /// テキストオーバーレイを描画
    private static func drawTextOverlay(width: CGFloat, height: CGFloat, record: RunningRecord) {
        let overlayHeight = height / 3.0
        let baseFontSize = overlayHeight / 10.0
        let lineHeight = baseFontSize * 1.4
        let padding = baseFontSize * 0.8

        let dateFont = UIFont.systemFont(ofSize: baseFontSize * 0.7, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)

        var yOffset = height - padding

        var lines: [(String, UIFont)] = []

        if let cal = record.formattedCalories {
            lines.append((cal, valueFont))
        }
        if let steps = record.formattedStepCount {
            lines.append((steps, valueFont))
        }
        if let hr = record.formattedAverageHeartRate {
            lines.append((hr, valueFont))
        }
        lines.append((record.formattedPace, valueFont))
        lines.append((record.formattedDuration, valueFont))
        lines.append((record.formattedDistance, valueFont))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d HH:mm"
        dateFormatter.locale = Locale(identifier: "ja_JP")
        lines.append((dateFormatter.string(from: record.date), dateFont))

        for (text, font) in lines {
            yOffset -= lineHeight
            let x = width - padding
            drawOutlinedText(text, at: CGPoint(x: x, y: yOffset), font: font)
        }
    }

    private static func drawOutlinedText(_ text: String, at point: CGPoint, font: UIFont) {
        let strokeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
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
}

// MARK: - Transferable Image (HDR対応)

struct TransferableImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            // 生データを保持（HDR情報を失わないため）
            // OrientationはCIImageが.applyOrientationPropertyで自動処理
            TransferableImage(data: data)
        }
    }

    enum TransferError: Error {
        case importFailed
    }
}

// MARK: - Kilometer Point

struct KilometerPoint: Identifiable {
    let id = UUID()
    let kilometer: Int
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Full Screen Map View

struct FullScreenMapView: View {
    let locations: [CLLocation]
    let kilometerPoints: [KilometerPoint]
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        locations.map { $0.coordinate }
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        coordinates.first
    }

    private var goalCoordinate: CLLocationCoordinate2D? {
        coordinates.last
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                // ルートライン
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 5)

                // スタート地点
                if let start = startCoordinate {
                    Annotation("スタート", coordinate: start) {
                        ZStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 32, height: 32)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // ゴール地点
                if let goal = goalCoordinate {
                    Annotation("ゴール", coordinate: goal) {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 32, height: 32)
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // 1kmごとのマーカー
                ForEach(kilometerPoints) { point in
                    Annotation("\(point.kilometer)km", coordinate: point.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.orange)
                                .frame(width: 28, height: 28)
                            Text("\(point.kilometer)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // 閉じるボタン
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
        .onAppear {
            if let region = regionToFitCoordinates(coordinates) {
                cameraPosition = .region(region)
            }
        }
    }

    private func regionToFitCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3

        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005),
            longitudeDelta: max(lonDelta, 0.005)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        RunDetailView(record: RunningRecord(
            id: UUID(),
            date: Date(),
            distanceInMeters: 5230,
            durationInSeconds: 1800,
            caloriesBurned: 320,
            averageHeartRate: 155,
            maxHeartRate: 178,
            minHeartRate: 120,
            cadence: 172,
            strideLength: 1.12,
            stepCount: 5160
        ))
    }
}
