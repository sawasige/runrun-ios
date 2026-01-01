import SwiftUI

struct RunDetailView: View {
    let record: RunningRecord

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
