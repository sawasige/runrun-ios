import SwiftUI
import MapKit
import CoreLocation
import HealthKit

struct RunDetailView: View {
    let record: RunningRecord

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var splits: [Split] = []
    @State private var isLoadingRoute = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    private let healthKitService = HealthKitService()

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
                    Map(position: $mapCameraPosition) {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(.blue, lineWidth: 4)
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
    }

    private func loadRouteData() async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        // 該当日のワークアウトを検索
        guard let workout = await findWorkout(for: record.date) else { return }

        // ルートを取得
        let locations = await healthKitService.fetchWorkoutRoute(for: workout)
        guard !locations.isEmpty else { return }

        // 座標配列に変換
        routeCoordinates = locations.map { $0.coordinate }

        // スプリットを計算
        splits = healthKitService.calculateSplits(from: locations)

        // カメラ位置を設定
        if let firstCoord = routeCoordinates.first {
            let region = MKCoordinateRegion(
                center: firstCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            mapCameraPosition = .region(region)
        }
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
