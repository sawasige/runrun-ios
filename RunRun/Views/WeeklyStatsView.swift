import SwiftUI
import Charts

struct WeeklyStatsView: View {
    let userProfile: UserProfile

    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric
    @State private var weeklyStats: [WeeklyRunningStats] = []
    @State private var isLoading = false
    @State private var error: Error?

    private let firestoreService = FirestoreService.shared

    init(user: UserProfile) {
        self.userProfile = user
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                errorView(error: error)
            } else if weeklyStats.isEmpty {
                emptyView
            } else {
                statsContent
            }
        }
        .navigationTitle("Weekly Trends")
        .navigationBarTitleDisplayMode(.large)
        .analyticsScreen("WeeklyStats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView(user: userProfile)
                } label: {
                    ProfileAvatarView(user: userProfile, size: 28)
                }
            }
        }
        .task {
            await loadStats()
        }
    }

    private var statsContent: some View {
        List {
            Section {
                weeklyChart
                    .frame(height: 200)
            }

            Section("Weekly Data") {
                ForEach(weeklyStats.reversed()) { stat in
                    WeeklyStatRow(stat: stat, useMetric: useMetric)
                }
            }
        }
    }

    private var weeklyChart: some View {
        Chart(weeklyStats) { stat in
            LineMark(
                x: .value("Week", stat.weekStartDate, unit: .weekOfYear),
                y: .value("Distance", stat.chartDistance(useMetric: useMetric))
            )
            .foregroundStyle(Color.accentColor)
            .symbol(.circle)

            AreaMark(
                x: .value("Week", stat.weekStartDate, unit: .weekOfYear),
                y: .value("Distance", stat.chartDistance(useMetric: useMetric))
            )
            .foregroundStyle(Color.accentColor.opacity(0.1))
        }
        .chartYAxisLabel(UnitFormatter.distanceUnit(useMetric: useMetric))
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No data available")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
    }

    private func loadStats() async {
        guard let userId = userProfile.id else { return }

        // データがない場合のみローディング表示（チラつき防止）
        if weeklyStats.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            weeklyStats = try await firestoreService.getUserWeeklyStats(userId: userId, weeks: 12)
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

private struct WeeklyStatRow: View {
    let stat: WeeklyRunningStats
    let useMetric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.formattedWeekRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(stat.formattedTotalDistance(useMetric: useMetric))
                    .font(.headline)
            }

            if stat.runCount > 0 {
                HStack(spacing: 16) {
                    Label(String(format: String(localized: "%d runs", comment: "Run count"), stat.runCount), systemImage: "figure.run")
                    Label(stat.formattedAveragePace(useMetric: useMetric), systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WeeklyStatsView(user: UserProfile(id: "preview", displayName: "Preview User", email: nil, iconName: "figure.run"))
    }
}
