import SwiftUI
import Charts

struct YearDetailView: View {
    @StateObject private var viewModel: YearDetailViewModel
    @EnvironmentObject private var syncService: SyncService

    let userProfile: UserProfile?

    init(userId: String, initialYear: Int? = nil) {
        self.userProfile = nil
        _viewModel = StateObject(wrappedValue: YearDetailViewModel(userId: userId, initialYear: initialYear))
    }

    init(user: UserProfile, initialYear: Int? = nil) {
        self.userProfile = user
        _viewModel = StateObject(wrappedValue: YearDetailViewModel(userId: user.id ?? "", initialYear: initialYear))
    }

    private var navigationTitle: String {
        String(format: String(localized: "%d Records", comment: "Year records title"), viewModel.selectedYear)
    }

    private func monthDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
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
        Group {
            if userProfile == nil {
                NavigationStack {
                    mainContent
                }
            } else {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 0) {
                    yearPickerSection
                    loadingView
                }
            } else if let error = viewModel.error {
                VStack(spacing: 0) {
                    yearPickerSection
                    errorView(error: error)
                }
            } else {
                statsListView
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let user = userProfile {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        ProfileAvatarView(user: user, size: 28)
                    }
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onAppear {
            AnalyticsService.logScreenView("YearDetail")
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedYear) {
            Task {
                await viewModel.loadMonthlyStats()
            }
        }
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            // 自分のデータの場合のみリロード
            if userProfile == nil {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var yearPickerSection: some View {
        VStack(spacing: 12) {
            Picker(String(localized: "Year"), selection: $viewModel.selectedYear) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text(MonthlyRunningStats.formattedYear(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack {
                Text("Yearly Total")
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
            Text("Loading...")
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
            Button("Reload") {
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
            // 年ピッカーセクション（スクロール領域内）
            Section {
                yearPickerSection
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Monthly Distance") {
                monthlyChart
                    .frame(height: 200)
            }

            Section("Totals") {
                LabeledContent("Distance") {
                    Text(viewModel.formattedTotalYearlyDistance)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                LabeledContent("Time", value: viewModel.formattedTotalDuration)
                LabeledContent("Count", value: String(format: String(localized: "%d runs", comment: "Run count"), viewModel.totalRunCount))
                if userProfile == nil, let calories = viewModel.formattedTotalCalories {
                    LabeledContent("Energy", value: calories)
                }
            }

            Section("Averages") {
                LabeledContent("Pace", value: viewModel.formattedAveragePace)
                LabeledContent("Distance/Run", value: viewModel.formattedAverageDistance)
                LabeledContent("Time/Run", value: viewModel.formattedAverageDuration)
            }

            if viewModel.bestMonthByDistance != nil || viewModel.bestDayByDistance != nil {
                Section("Highlights") {
                    // 月のハイライト
                    if let best = viewModel.bestMonthByDistance {
                        NavigationLink {
                            if let user = userProfile {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            } else {
                                MonthDetailView(userId: viewModel.userId, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Best Distance Month", value: "\(best.shortMonthName) (\(best.formattedTotalDistance))")
                        }
                    }
                    if let best = viewModel.bestMonthByDuration {
                        NavigationLink {
                            if let user = userProfile {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            } else {
                                MonthDetailView(userId: viewModel.userId, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Best Duration Month", value: "\(best.shortMonthName) (\(best.formattedTotalDuration))")
                        }
                    }
                    if let best = viewModel.mostRunsMonth {
                        NavigationLink {
                            if let user = userProfile {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            } else {
                                MonthDetailView(userId: viewModel.userId, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Most Runs Month", value: "\(best.shortMonthName) (\(String(format: String(localized: "%d runs", comment: "Run count"), best.runCount)))")
                        }
                    }
                    // 日のハイライト
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Best Distance Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDistance))")
                        }
                    }
                    if let best = viewModel.bestDayByDuration {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Best Duration Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = viewModel.fastestDay {
                        NavigationLink {
                            RunDetailView(
                                record: fastest,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Fastest Day", value: "\(monthDayString(from: fastest.date)) (\(fastest.formattedPace))")
                        }
                    }
                }
            }

            Section("Monthly Records") {
                ForEach(Array(filteredMonthlyStats.reversed().enumerated()), id: \.element.id) { index, stats in
                    NavigationLink {
                        if let user = userProfile {
                            MonthDetailView(user: user, year: stats.year, month: stats.month)
                        } else {
                            MonthDetailView(userId: viewModel.userId, year: stats.year, month: stats.month)
                        }
                    } label: {
                        MonthlyStatsRow(stats: stats)
                            .accessibilityIdentifier(index == 0 ? "first_month_row" : "month_row_\(index)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var monthlyChart: some View {
        Chart(viewModel.monthlyStats) { stats in
            BarMark(
                x: .value(String(localized: "Month"), stats.shortMonthName),
                y: .value(String(localized: "Distance"), stats.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = viewModel.bestMonthByDistance, stats.month == best.month, best.totalDistanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.totalDistanceInKilometers))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartYAxisLabel("km")
    }
}

struct MonthlyStatsRow: View {
    let stats: MonthlyRunningStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.formattedMonth)
                    .font(.headline)
                Text(String(format: String(localized: "%d runs", comment: "Run count"), stats.runCount))
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
    YearDetailView(userId: "preview")
}
