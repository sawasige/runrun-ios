import SwiftUI

/// 目標進捗を表示するコンポーネント
struct GoalProgressView: View {
    let currentDistance: Double
    let targetDistance: Double
    let useMetric: Bool

    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return currentDistance / targetDistance
    }

    private var isAchieved: Bool {
        currentDistance >= targetDistance
    }

    private var progressPercentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goal Progress", comment: "Goal progress section title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(UnitFormatter.formatDistance(currentDistance, useMetric: useMetric, decimals: 1))
                    .font(.title2)
                    .fontWeight(.bold)
                Text("/")
                    .foregroundStyle(.secondary)
                Text(UnitFormatter.formatDistance(targetDistance, useMetric: useMetric, decimals: 1))
                    .foregroundStyle(.secondary)
                Text("(\(progressPercentage)%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(progress, 1.0))
                .tint(isAchieved ? .green : .accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        GoalProgressView(currentDistance: 80, targetDistance: 100, useMetric: true)
        GoalProgressView(currentDistance: 105, targetDistance: 100, useMetric: true)
        GoalProgressView(currentDistance: 50, targetDistance: 100, useMetric: false)
    }
    .padding()
}
