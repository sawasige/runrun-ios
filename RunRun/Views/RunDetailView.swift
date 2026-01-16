import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import Charts
import ImageIO
import FirebaseAuth

struct RunDetailView: View {
    @State private var record: RunningRecord
    let userProfile: UserProfile
    @State private var previousRecord: RunningRecord?
    @State private var nextRecord: RunningRecord?
    @State private var isLoadingAdjacent = false

    private let firestoreService = FirestoreService.shared

    private var isOwnRecord: Bool {
        if ScreenshotMode.isEnabled {
            return userProfile.id == MockDataProvider.currentUserId
        }
        return userProfile.id == Auth.auth().currentUser?.uid
    }

    private var userId: String {
        userProfile.id ?? ""
    }

    init(record: RunningRecord, user: UserProfile) {
        _record = State(initialValue: record)
        self.userProfile = user
    }

    @State private var routeLocations: [CLLocation] = []
    @State private var splits: [Split] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var routeSegments: [RouteSegment] = []
    @State private var isLoadingRoute = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showFullScreenMap = false
    @State private var showShareSettings = false

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
        isLoadingAdjacent = true

        async let prevTask = firestoreService.getAdjacentRun(userId: userId, currentDate: record.date, direction: .previous)
        async let nextTask = firestoreService.getAdjacentRun(userId: userId, currentDate: record.date, direction: .next)

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
                                .accessibilityIdentifier("expand_map_button")
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
                                    Text(UnitFormatter.paceUnit)
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
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if isOwnRecord {
                        Button {
                            showShareSettings = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    NavigationLink {
                        ProfileView(user: userProfile)
                    } label: {
                        ProfileAvatarView(user: userProfile, size: 28)
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
                kilometerPoints: calculateKilometerPoints()
            )
        }
        .sheet(isPresented: $showShareSettings) {
            RunShareSettingsView(record: record, isPresented: $showShareSettings)
        }
        .task {
            AnalyticsService.logEvent("view_run_detail", parameters: [
                "is_own_record": isOwnRecord
            ])
            await loadRouteData()
            await loadAdjacentRecords()
        }
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
                    Annotation("\(point.kilometer)\(UnitFormatter.distanceUnit)", coordinate: point.coordinate) {
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

        // スクリーンショットモードならモックデータを使用
        if ScreenshotMode.isEnabled {
            routeSegments = MockDataProvider.imperialPalaceRouteSegments
            // routeLocationsも設定（地図表示の条件に必要）
            routeLocations = routeSegments.flatMap { segment in
                segment.coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            }
            mapCameraPosition = .region(MKCoordinateRegion(
                center: MockDataProvider.routeCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
            return
        }

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

    /// 単位ごとの座標を計算（1km or 1mi）
    private func calculateKilometerPoints() -> [KilometerPoint] {
        guard routeLocations.count >= 2 else { return [] }

        let interval: Double = DistanceUnit.current == .miles ? 1609.34 : 1000.0

        var points: [KilometerPoint] = []
        var currentSegment = 1
        var accumulatedDistance: Double = 0

        for i in 1..<routeLocations.count {
            let distance = routeLocations[i].distance(from: routeLocations[i - 1])
            accumulatedDistance += distance

            if accumulatedDistance >= interval {
                points.append(KilometerPoint(
                    kilometer: currentSegment,
                    coordinate: routeLocations[i].coordinate
                ))
                currentSegment += 1
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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // グラデーションルートマップ
                GradientRouteMapView(
                    routeSegments: routeSegments,
                    fastPace: fastPace,
                    slowPace: slowPace,
                    startCoordinate: routeCoordinates.first,
                    goalCoordinate: routeCoordinates.last,
                    kilometerPoints: kilometerPoints
                )
                .ignoresSafeArea()

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
        RunDetailView(
            record: RunningRecord(
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
            ),
            user: UserProfile(id: "preview", displayName: "Preview User", email: nil, iconName: "figure.run")
        )
    }
}
