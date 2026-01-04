import SwiftUI
import Charts

struct YearlySummaryView: View {
    let year: Int
    let monthlyStats: [MonthlyRunningStats]
    var userProfile: UserProfile?

    private var totalDistance: Double {
        monthlyStats.reduce(0) { $0 + $1.totalDistanceInKilometers }
    }

    private var totalDuration: TimeInterval {
        monthlyStats.reduce(0) { $0 + $1.totalDurationInSeconds }
    }

    private var totalRuns: Int {
        monthlyStats.reduce(0) { $0 + $1.runCount }
    }

    private var averagePace: TimeInterval? {
        guard totalDistance > 0 else { return nil }
        return totalDuration / totalDistance
    }

    private var bestMonth: MonthlyRunningStats? {
        monthlyStats.max { $0.totalDistanceInKilometers < $1.totalDistanceInKilometers }
    }

    private var longestRun: MonthlyRunningStats? {
        // 各月の平均距離が最大の月（概算）
        monthlyStats.filter { $0.runCount > 0 }
            .max { ($0.totalDistanceInKilometers / Double($0.runCount)) < ($1.totalDistanceInKilometers / Double($1.runCount)) }
    }

    private var formattedTotalDistance: String {
        String(format: "%.1f km", totalDistance)
    }

    private var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }

    private var formattedAveragePace: String {
        guard let pace = averagePace else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private var formattedAverageDistancePerRun: String {
        guard totalRuns > 0 else { return "0.0 km" }
        return String(format: "%.2f km", totalDistance / Double(totalRuns))
    }

    var body: some View {
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

            // 年間チャート
            Section {
                yearlyChart
                    .frame(height: 200)
            }

            // メイン統計
            Section("総合") {
                LabeledContent("総距離", value: formattedTotalDistance)
                LabeledContent("総時間", value: formattedTotalDuration)
                LabeledContent("ラン回数", value: "\(totalRuns)回")
            }

            // 効率
            Section("効率") {
                LabeledContent("平均ペース", value: formattedAveragePace)
                LabeledContent("平均距離/回", value: formattedAverageDistancePerRun)
            }

            // ハイライト
            if let best = bestMonth, best.totalDistanceInKilometers > 0 {
                Section("ハイライト") {
                    LabeledContent("ベスト月", value: "\(best.month)月 (\(best.formattedTotalDistance))")
                    if let mostActive = monthlyStats.filter({ $0.runCount > 0 }).max(by: { $0.runCount < $1.runCount }) {
                        LabeledContent("最多ラン月", value: "\(mostActive.month)月 (\(mostActive.runCount)回)")
                    }
                }
            }

            // 月別詳細
            Section("月別詳細") {
                ForEach(monthlyStats.reversed()) { stats in
                    MonthSummaryRow(stats: stats)
                }
            }
        }
        .navigationTitle(String(year) + "年サマリー")
        .toolbar {
            if let user = userProfile {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
    }

    private var yearlyChart: some View {
        Chart(monthlyStats) { stats in
            BarMark(
                x: .value("月", "\(stats.month)月"),
                y: .value("距離", stats.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = bestMonth, stats.month == best.month {
                RuleMark(y: .value("ベスト", best.totalDistanceInKilometers))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartYAxisLabel("km")
    }
}

private struct MonthSummaryRow: View {
    let stats: MonthlyRunningStats

    var body: some View {
        HStack {
            Text("\(stats.month)月")
                .frame(width: 40, alignment: .leading)

            if stats.runCount > 0 {
                Spacer()
                Text("\(stats.runCount)回")
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                Text(stats.formattedTotalDistance)
                    .fontWeight(.medium)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Spacer()
                Text("-")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        YearlySummaryView(year: 2025, monthlyStats: [
            MonthlyRunningStats(id: UUID(), year: 2025, month: 1, totalDistanceInMeters: 50000, totalDurationInSeconds: 18000, runCount: 10),
            MonthlyRunningStats(id: UUID(), year: 2025, month: 2, totalDistanceInMeters: 45000, totalDurationInSeconds: 16200, runCount: 9),
            MonthlyRunningStats(id: UUID(), year: 2025, month: 3, totalDistanceInMeters: 60000, totalDurationInSeconds: 21600, runCount: 12)
        ])
    }
}
