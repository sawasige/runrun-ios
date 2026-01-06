import SwiftUI
import Charts
import FirebaseAuth

struct WeeklyStatsView: View {
    let userId: String?
    let userProfile: UserProfile?

    @State private var weeklyStats: [WeeklyRunningStats] = []
    @State private var isLoading = false
    @State private var error: Error?

    private let firestoreService = FirestoreService.shared

    init(userId: String? = nil, userProfile: UserProfile? = nil) {
        self.userId = userId
        self.userProfile = userProfile
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
        .navigationTitle("週間推移")
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
        .task {
            await loadStats()
        }
    }

    private var statsContent: some View {
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

            Section {
                weeklyChart
                    .frame(height: 200)
            }

            Section("週間データ") {
                ForEach(weeklyStats.reversed()) { stat in
                    WeeklyStatRow(stat: stat)
                }
            }
        }
    }

    private var weeklyChart: some View {
        Chart(weeklyStats) { stat in
            LineMark(
                x: .value("週", stat.weekStartDate, unit: .weekOfYear),
                y: .value("距離", stat.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor)
            .symbol(.circle)

            AreaMark(
                x: .value("週", stat.weekStartDate, unit: .weekOfYear),
                y: .value("距離", stat.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.opacity(0.1))
        }
        .chartYAxisLabel("km")
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
            Text("データがありません")
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
        // 指定されたuserIdを使用、なければ現在のユーザー
        guard let targetUserId = userId ?? Auth.auth().currentUser?.uid else { return }

        isLoading = true
        error = nil

        do {
            weeklyStats = try await firestoreService.getUserWeeklyStats(userId: targetUserId, weeks: 12)
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

private struct WeeklyStatRow: View {
    let stat: WeeklyRunningStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.formattedWeekRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(stat.formattedTotalDistance)
                    .font(.headline)
            }

            if stat.runCount > 0 {
                HStack(spacing: 16) {
                    Label(String(format: String(localized: "%d runs", comment: "Run count"), stat.runCount), systemImage: "figure.run")
                    Label(stat.formattedAveragePace, systemImage: "speedometer")
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
        WeeklyStatsView()
    }
}
