import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import PhotosUI
import Charts
import ImageIO
import FirebaseAuth

struct RunDetailView: View {
    @State private var record: RunningRecord
    let isOwnRecord: Bool
    let userProfile: UserProfile?
    let userId: String?
    @State private var previousRecord: RunningRecord?
    @State private var nextRecord: RunningRecord?
    @State private var isLoadingAdjacent = false

    private let firestoreService = FirestoreService.shared

    init(record: RunningRecord, isOwnRecord: Bool = true, userProfile: UserProfile? = nil, userId: String? = nil) {
        _record = State(initialValue: record)
        self.isOwnRecord = isOwnRecord
        self.userProfile = userProfile
        self.userId = userId ?? (isOwnRecord ? nil : userProfile?.id)
    }

    @State private var routeLocations: [CLLocation] = []
    @State private var splits: [Split] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var routeSegments: [RouteSegment] = []
    @State private var isLoadingRoute = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showFullScreenMap = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showExportPreview = false
    @State private var exportImageData: Data?

    private let healthKitService = HealthKitService()

    private var routeCoordinates: [CLLocationCoordinate2D] {
        routeLocations.map { $0.coordinate }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        return formatter.string(from: record.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter.string(from: record.date)
    }

    private var canGoToPrevious: Bool {
        previousRecord != nil
    }

    private var canGoToNext: Bool {
        nextRecord != nil
    }

    private func goToPrevious() {
        guard let prev = previousRecord else { return }
        record = prev
        resetAllData()
        Task {
            await loadRouteData()
            await loadAdjacentRecords()
        }
    }

    private func goToNext() {
        guard let next = nextRecord else { return }
        record = next
        resetAllData()
        Task {
            await loadRouteData()
            await loadAdjacentRecords()
        }
    }

    private func resetAllData() {
        // 前後レコードをリセット（ボタン状態を更新）
        previousRecord = nil
        nextRecord = nil
        // ルートデータはリセットしない（チラつき防止）
        // 新しいデータが読み込まれた時に更新される
    }

    private func clearRouteData() {
        routeLocations = []
        splits = []
        heartRateSamples = []
        routeSegments = []
    }

    private func loadAdjacentRecords() async {
        guard let uid = userId ?? Auth.auth().currentUser?.uid else { return }
        isLoadingAdjacent = true

        async let prevTask = firestoreService.getAdjacentRun(userId: uid, currentDate: record.date, direction: .previous)
        async let nextTask = firestoreService.getAdjacentRun(userId: uid, currentDate: record.date, direction: .next)

        previousRecord = try? await prevTask
        nextRecord = try? await nextTask
        isLoadingAdjacent = false
    }

    private var runNavigationButtons: some View {
        HStack(spacing: 0) {
            Button {
                goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }
            .disabled(!canGoToPrevious)
            .opacity(canGoToPrevious ? 1 : 0.3)

            Divider()
                .frame(height: 30)

            Button {
                goToNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }
            .disabled(!canGoToNext)
            .opacity(canGoToNext ? 1 : 0.3)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                // ユーザー情報セクション（他人の記録の場合）
                if let user = userProfile {
                    Section {
                        NavigationLink {
                            ProfileView(user: user)
                        } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(user: user, size: 40)
                                Text(user.displayName)
                                    .font(.headline)
                                Spacer()
                            }
                        }
                    }
                }

                // 記録サマリセクション
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text(formattedTime)
                                .font(.headline)
                            Text("Start")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 32) {
                            StatItem(value: record.formattedDistance, label: String(localized: "Distance"))
                            StatItem(value: record.formattedDuration, label: String(localized: "Duration"))
                            StatItem(value: record.formattedPace, label: String(localized: "Pace"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // 地図セクション（自分の記録のみ）
                if isOwnRecord {
                    if !routeCoordinates.isEmpty {
                        Section {
                            ZStack(alignment: .bottomTrailing) {
                                mapContent(isExpanded: false)
                                    .allowsHitTesting(false)

                                Button {
                                    showFullScreenMap = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .padding(8)
                            }
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
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
                }

                // スプリットセクション（自分の記録のみ）
                if isOwnRecord && !splits.isEmpty {
                    Section("Splits") {
                        ForEach(splits) { split in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(split.formattedKilometer)
                                    Spacer()
                                    Text(split.formattedPace)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                    Text("/km")
                                        .foregroundStyle(.secondary)
                                }

                                // 心拍数行
                                if let avgHR = split.formattedAverageHeartRate {
                                    HStack(spacing: 12) {
                                        Label("\(avgHR) bpm", systemImage: "heart.fill")
                                            .foregroundStyle(.red)
                                        if let maxHR = split.maxHeartRate {
                                            Text("max \(Int(maxHR))")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // 心拍数推移グラフ（自分の記録のみ）
                if isOwnRecord && !heartRateSamples.isEmpty {
                    Section("Heart Rate Graph") {
                        HeartRateChartView(samples: heartRateSamples)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // 心拍数セクション
                if record.averageHeartRate != nil || record.maxHeartRate != nil || record.minHeartRate != nil {
                    Section("Heart Rate") {
                        if let avg = record.formattedAverageHeartRate {
                            LabeledContent("Average", value: avg)
                        }
                        if let max = record.formattedMaxHeartRate {
                            LabeledContent("Max", value: max)
                        }
                        if let min = record.formattedMinHeartRate {
                            LabeledContent("Min", value: min)
                        }
                    }
                }

                // 効率セクション
                if record.cadence != nil || record.strideLength != nil || record.stepCount != nil {
                    Section("Efficiency") {
                        if let cadence = record.formattedCadence {
                            LabeledContent("Cadence", value: cadence)
                        }
                        if let stride = record.formattedStrideLength {
                            LabeledContent("Stride", value: stride)
                        }
                        if let steps = record.formattedStepCount {
                            LabeledContent("Steps", value: steps)
                        }
                    }
                }

                // エネルギーセクション
                if let calories = record.formattedCalories {
                    Section("Energy") {
                        LabeledContent("Calories Burned", value: calories)
                    }
                }

                // フローティングボタン分の余白
                Section {
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                }
            }

            // フローティング前後移動ボタン
            runNavigationButtons
                .padding()
                .padding(.bottom, 8)
        }
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.large)
        .analyticsScreen("RunDetail")
        .toolbar {
            if let user = userProfile {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            } else if isOwnRecord {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            let percentiles = pacePercentiles
            FullScreenMapView(
                routeCoordinates: routeCoordinates,
                routeSegments: routeSegments,
                fastPace: percentiles.fast,
                slowPace: percentiles.slow,
                kilometerPoints: calculateKilometerPoints(),
                cameraPosition: mapCameraPosition
            )
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
            AnalyticsService.logEvent("view_run_detail", parameters: [
                "is_own_record": isOwnRecord
            ])
            await loadRouteData()
            await loadAdjacentRecords()
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

    /// ペースのパーセンタイル（10%〜90%）
    private var pacePercentiles: (fast: TimeInterval, slow: TimeInterval) {
        RouteSegment.calculatePacePercentiles(from: routeSegments)
    }

    /// マップコンテンツ（縮小時・拡大時で共通のMap）
    @ViewBuilder
    private func mapContent(isExpanded: Bool) -> some View {
        Map(position: $mapCameraPosition) {
            // 縮小時はアクセントカラー一色、拡大時はペース別色分け
            if isExpanded && !routeSegments.isEmpty {
                let percentiles = pacePercentiles
                ForEach(routeSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.color(fastPace: percentiles.fast, slowPace: percentiles.slow), lineWidth: 5)
                }
            } else {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(Color.accentColor, lineWidth: 4)
            }

            // 拡大時のみマーカーを表示
            if isExpanded {
                // スタート地点
                if let start = routeCoordinates.first {
                    Annotation("Start", coordinate: start) {
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
                if let goal = routeCoordinates.last {
                    Annotation("Goal", coordinate: goal) {
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
                ForEach(calculateKilometerPoints()) { point in
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
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private func loadRouteData() async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        // 該当日のワークアウトを検索
        guard let workout = await findWorkout(for: record.date) else {
            clearRouteData()
            return
        }

        // ルートと心拍数サンプルを並列取得
        async let locationsTask = healthKitService.fetchWorkoutRoute(for: workout)
        async let hrSamplesTask = healthKitService.fetchHeartRateSamples(for: workout)

        let (locations, hrSamples) = await (locationsTask, hrSamplesTask)

        guard !locations.isEmpty else {
            clearRouteData()
            return
        }

        // ロケーション配列を保存
        routeLocations = locations
        heartRateSamples = hrSamples

        // スプリットを計算（心拍数データ付き）
        var calculatedSplits = healthKitService.calculateSplits(from: locations)
        calculatedSplits = healthKitService.enrichSplitsWithHeartRate(
            splits: calculatedSplits,
            heartRateSamples: hrSamples
        )
        splits = calculatedSplits

        // ルートセグメントを計算（ペース別色分け用、10m単位）
        routeSegments = healthKitService.calculateRouteSegments(from: locations, segmentDistance: 10)

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
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let data = composedHEIFData {
                    HDRImageView(imageData: data)
                } else if isProcessing {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
            .alert("Saved", isPresented: $showSaveSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Saved to Photos")
            }
            .alert("Error", isPresented: .init(
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
                saveError = String(localized: "Photo access not authorized")
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

        let dateFont = UIFont.rounded(ofSize: baseFontSize * 0.7, weight: .medium)
        let valueFont = UIFont.rounded(ofSize: baseFontSize, weight: .semibold)

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
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
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
    let routeCoordinates: [CLLocationCoordinate2D]
    let routeSegments: [RouteSegment]
    let fastPace: TimeInterval
    let slowPace: TimeInterval
    let kilometerPoints: [KilometerPoint]
    let cameraPosition: MapCameraPosition

    @Environment(\.dismiss) private var dismiss
    @State private var localCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Map(position: $localCameraPosition) {
                    // ペース別色分けルート
                    if !routeSegments.isEmpty {
                        ForEach(routeSegments) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(segment.color(fastPace: fastPace, slowPace: slowPace), lineWidth: 5)
                        }
                    } else {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(Color.accentColor, lineWidth: 5)
                    }

                    // スタート地点
                    if let start = routeCoordinates.first {
                        Annotation("Start", coordinate: start) {
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
                    if let goal = routeCoordinates.last {
                        Annotation("Goal", coordinate: goal) {
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
                .ignoresSafeArea(edges: [.horizontal, .top])
                .safeAreaPadding(.bottom, geometry.safeAreaInsets.bottom)

                VStack(alignment: .leading, spacing: 8) {
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

                    // ペース凡例
                    if !routeSegments.isEmpty {
                        paceLegend
                    }
                }
                .padding(.top, geometry.safeAreaInsets.top + 8)
                .padding(.leading, 16)
            }
        }
        .onAppear {
            localCameraPosition = cameraPosition
        }
    }

    private var paceLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, text: String(localized: "Fast"))
            legendItem(color: .yellow, text: String(localized: "Normal"))
            legendItem(color: .red, text: String(localized: "Slow"))
        }
        .font(.caption2)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundStyle(.primary)
        }
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
