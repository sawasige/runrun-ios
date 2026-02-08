import SwiftUI

/// 目標進捗を表示するコンポーネント
struct GoalProgressView: View {
    let currentDistance: Double
    let targetDistance: Double
    let useMetric: Bool
    var isCurrentPeriod: Bool = false
    var onEdit: (() -> Void)?

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

    /// シマーアニメーションを表示するかどうか
    private var showShimmer: Bool {
        isCurrentPeriod && !isAchieved && progress > 0
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
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Edit Goal", comment: "Edit goal button accessibility label"))
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

            ShimmerProgressBar(
                progress: min(progress, 1.0),
                tint: isAchieved ? .green : .accentColor,
                showShimmer: showShimmer
            )
        }
        .padding(.vertical, 4)
    }
}

/// シマーアニメーション付きプログレスバー
private struct ShimmerProgressBar: View {
    let progress: Double
    let tint: Color
    let showShimmer: Bool

    var body: some View {
        GeometryReader { geometry in
            let progressWidth = geometry.size.width * progress

            ZStack(alignment: .leading) {
                // 背景
                Capsule()
                    .fill(Color.primary.opacity(0.1))

                // 進捗バー + シマー
                Capsule()
                    .fill(tint)
                    .frame(width: progressWidth)
                    .overlay {
                        if showShimmer && progressWidth > 0 {
                            ShimmerOverlay()
                                .clipShape(Capsule())
                        }
                    }
            }
        }
        .frame(height: 4)
    }
}

/// シマーオーバーレイ（左側フェードイン、右側シャープ）
private struct ShimmerOverlay: View {
    /// シマーの固定幅（ポイント）
    private let shimmerWidth: CGFloat = 40
    /// シマーの移動速度（ポイント/秒）
    private let shimmerSpeed: CGFloat = 50
    /// シマーの発生間隔（秒）- 線グラフの点滅と同期
    private let shimmerInterval: Double = 2.4

    @State private var startDate = Date()

    private let shimmerGradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0), location: 0),
            .init(color: .white.opacity(0.6), location: 0.8),
            .init(color: .white.opacity(0), location: 0.81)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 表示中のシマーのオフセット一覧を計算
    private func visibleShimmerOffsets(for width: CGFloat, elapsed: Double) -> [CGFloat] {
        var offsets: [CGFloat] = []

        // シマーが画面を横断するのにかかる時間
        let travelDuration = (width + shimmerWidth) / shimmerSpeed

        // 現在のシマーのインデックス（何番目のシマーが発生したか）
        let currentShimmerIndex = Int(elapsed / shimmerInterval)

        // 最大でいくつのシマーが同時に表示されうるか
        let maxVisibleShimmers = Int(ceil(travelDuration / shimmerInterval)) + 1

        // 現在表示される可能性のあるシマーをチェック
        for i in max(0, currentShimmerIndex - maxVisibleShimmers)...currentShimmerIndex {
            // このシマーが発生してからの経過時間
            let shimmerStartTime = Double(i) * shimmerInterval
            let shimmerElapsed = elapsed - shimmerStartTime

            // まだ発生していない
            if shimmerElapsed < 0 { continue }

            // シマーの現在位置
            let offsetX = -shimmerWidth + shimmerElapsed * shimmerSpeed

            // 画面内にいるかチェック
            if offsetX >= -shimmerWidth && offsetX <= width {
                offsets.append(offsetX)
            }
        }

        return offsets
    }

    var body: some View {
        SwiftUI.TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            GeometryReader { geometry in
                let offsets = visibleShimmerOffsets(for: geometry.size.width, elapsed: elapsed)
                ForEach(Array(offsets.enumerated()), id: \.offset) { _, offsetX in
                    shimmerGradient
                        .frame(width: shimmerWidth)
                        .offset(x: offsetX)
                }
            }
        }
        .onAppear {
            startDate = Date()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("現在の期間（シマーあり）")
            .font(.caption)
        GoalProgressView(currentDistance: 60, targetDistance: 100, useMetric: true, isCurrentPeriod: true)

        Divider()

        Text("過去の期間（シマーなし）")
            .font(.caption)
        GoalProgressView(currentDistance: 80, targetDistance: 100, useMetric: true, isCurrentPeriod: false)

        Divider()

        Text("目標達成済み（シマーなし）")
            .font(.caption)
        GoalProgressView(currentDistance: 105, targetDistance: 100, useMetric: true, isCurrentPeriod: true)
    }
    .padding()
}
