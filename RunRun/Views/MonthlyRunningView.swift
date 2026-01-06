import SwiftUI
import Charts

struct MonthlyRunningView: View {
    @StateObject private var viewModel: MonthlyRunningViewModel

    let userProfile: UserProfile?

    init(userId: String, userName: String? = nil) {
        self.userProfile = nil
        _viewModel = StateObject(wrappedValue: MonthlyRunningViewModel(userId: userId))
    }

    init(user: UserProfile) {
        self.userProfile = user
        _viewModel = StateObject(wrappedValue: MonthlyRunningViewModel(userId: user.id ?? ""))
    }

    private var navigationTitle: String {
        userProfile != nil ? "記録" : "ランニング記録"
    }

    /// リストには今月までの月のみ表示（未来の月は除外）
    private var filteredMonthlyStats: [MonthlyRunningStats] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        return viewModel.monthlyStats.filter { stats in
            if stats.year < currentYear {
                return true
            } else if stats.year == currentYear {
                return stats.month <= currentMonth
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                yearPickerSection

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else {
                    statsListView
                }
            }
            .navigationTitle(navigationTitle)
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
                await viewModel.onAppear()
            }
            .onAppear {
                AnalyticsService.logScreenView("MonthlyRunning")
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onChange(of: viewModel.selectedYear) {
                Task {
                    await viewModel.loadMonthlyStats()
                }
            }
        }
    }

    private var yearPickerSection: some View {
        VStack(spacing: 12) {
            Picker("年", selection: $viewModel.selectedYear) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text(verbatim: "\(year)年").tag(year)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack {
                Text("年間合計")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedTotalYearlyDistance)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
        }
        .padding(.top)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .foregroundStyle(.secondary)
                .padding(.top)
            Spacer()
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("再読み込み") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var statsListView: some View {
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
                monthlyChart
                    .frame(height: 200)
            }

            Section("年間サマリー") {
                NavigationLink {
                    YearlySummaryView(year: viewModel.selectedYear, monthlyStats: viewModel.monthlyStats, userProfile: userProfile)
                } label: {
                    HStack {
                        Label("詳細を見る", systemImage: "chart.bar.doc.horizontal")
                        Spacer()
                        Text(viewModel.formattedTotalYearlyDistance)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("週間推移") {
                NavigationLink {
                    WeeklyStatsView(userId: viewModel.userId, userProfile: userProfile)
                } label: {
                    Label("過去12週間の推移", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            Section("月別記録") {
                ForEach(filteredMonthlyStats.reversed()) { stats in
                    NavigationLink {
                        if let user = userProfile {
                            MonthDetailView(user: user, year: stats.year, month: stats.month)
                        } else {
                            MonthDetailView(userId: viewModel.userId, year: stats.year, month: stats.month)
                        }
                    } label: {
                        MonthlyStatsRow(stats: stats)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var monthlyChart: some View {
        Chart(viewModel.monthlyStats) { stats in
            BarMark(
                x: .value("月", "\(stats.month)月"),
                y: .value("距離", stats.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.gradient)
        }
        .chartYAxisLabel("km")
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct MonthlyStatsRow: View {
    let stats: MonthlyRunningStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.formattedMonth)
                    .font(.headline)
                Text("\(stats.runCount)回")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(stats.formattedTotalDistance)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(stats.totalDistanceInKilometers > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MonthlyRunningView(userId: "preview")
}
