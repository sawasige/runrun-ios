import SwiftUI
import MapKit
import CoreLocation
import HealthKit

struct RunDetailView: View {
    let record: RunningRecord

    @State private var routeLocations: [CLLocation] = []
    @State private var splits: [Split] = []
    @State private var isLoadingRoute = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showFullScreenMap = false
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
        .task {
            await loadRouteData()
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            FullScreenMapView(
                locations: routeLocations,
                kilometerPoints: calculateKilometerPoints()
            )
        }
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
