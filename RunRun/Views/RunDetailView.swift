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
    @State private var exportImage: UIImage?
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
            if let image = exportImage {
                RunExportPreviewView(
                    originalImage: image,
                    record: record
                )
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let image = try await item.loadTransferable(type: TransferableImage.self) {
                await MainActor.run {
                    exportImage = image.image
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

struct RunExportPreviewView: View {
    let originalImage: UIImage
    let record: RunningRecord

    @Environment(\.dismiss) private var dismiss
    @State private var composedImage: UIImage?
    @State private var isProcessing = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = composedImage {
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
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(composedImage == nil)
                }
            }
            .task {
                await composeImage()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = composedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func composeImage() async {
        isProcessing = true

        let image = originalImage
        let rec = record

        let result = await Task.detached(priority: .userInitiated) {
            await ImageComposer.compose(baseImage: image, record: rec)
        }.value

        await MainActor.run {
            composedImage = result
            isProcessing = false
        }
    }
}

// MARK: - Image Composer

import CoreImage

enum ImageComposer {
    static func compose(baseImage: UIImage, record: RunningRecord) async -> UIImage? {
        // まず画像のOrientationを正規化（回転問題を修正）
        let normalizedImage = normalizeOrientation(baseImage)

        let width = normalizedImage.size.width
        let height = normalizedImage.size.height

        // UIGraphicsImageRendererで描画（HDR保持のためextended rangeを使用）
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .extended  // HDR対応
        format.scale = normalizedImage.scale

        let renderer = UIGraphicsImageRenderer(size: normalizedImage.size, format: format)

        let result = renderer.image { context in
            // 元画像を描画
            normalizedImage.draw(at: .zero)

            // フォントサイズを画像の1/3に収まるように計算
            let overlayHeight = height / 3.0
            let baseFontSize = overlayHeight / 10.0
            let lineHeight = baseFontSize * 1.4
            let padding = baseFontSize * 0.8

            let dateFont = UIFont.systemFont(ofSize: baseFontSize * 0.7, weight: .medium)
            let valueFont = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)

            // 右下からの開始位置
            var yOffset = height - padding

            // テキスト行を収集（ラベルなし、値と単位のみ）
            var lines: [(String, UIFont)] = []

            // カロリー（あれば）
            if let cal = record.formattedCalories {
                lines.append((cal, valueFont))
            }

            // 歩数（あれば）
            if let steps = record.formattedStepCount {
                lines.append((steps, valueFont))
            }

            // 平均心拍数（あれば）
            if let hr = record.formattedAverageHeartRate {
                lines.append((hr, valueFont))
            }

            // ペース
            lines.append((record.formattedPace, valueFont))

            // 時間
            lines.append((record.formattedDuration, valueFont))

            // 距離
            lines.append((record.formattedDistance, valueFont))

            // 日時
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/M/d HH:mm"
            dateFormatter.locale = Locale(identifier: "ja_JP")
            lines.append((dateFormatter.string(from: record.date), dateFont))

            // 下から上に向かって描画
            for (text, font) in lines {
                yOffset -= lineHeight
                let x = width - padding
                drawOutlinedText(text, at: CGPoint(x: x, y: yOffset), font: font, width: width)
            }
        }

        return result
    }

    /// 画像のOrientationを正規化（回転を適用した状態にする）
    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.preferredRange = .extended  // HDR保持

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }

    private static func drawOutlinedText(_ text: String, at point: CGPoint, font: UIFont, width: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let strokeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = (text as NSString).size(withAttributes: fillAttributes)
        let drawPoint = CGPoint(x: point.x - textSize.width, y: point.y)

        // 縁取り（複数方向にオフセットして描画）
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

        // 白文字
        (text as NSString).draw(at: drawPoint, withAttributes: fillAttributes)
    }
}

// MARK: - Transferable Image

struct TransferableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return TransferableImage(image: image)
        }
    }

    enum TransferError: Error {
        case importFailed
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
