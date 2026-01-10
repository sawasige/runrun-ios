import SwiftUI
import Charts

struct YearDetailView: View {
    @StateObject private var viewModel: YearDetailViewModel

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

            Section {
                monthlyChart
                    .frame(height: 200)
            }

            Section("Overall") {
                LabeledContent("Total Distance", value: viewModel.formattedTotalYearlyDistance)
                LabeledContent("Total Time", value: viewModel.formattedTotalDuration)
                LabeledContent("Run Count", value: String(format: String(localized: "%d runs", comment: "Run count"), viewModel.totalRunCount))
                if userProfile == nil, let calories = viewModel.formattedTotalCalories {
                    LabeledContent("Energy", value: calories)
                }
            }

            Section("Efficiency") {
                LabeledContent("Average Pace", value: viewModel.formattedAveragePace)
                LabeledContent("Avg Distance/Run", value: viewModel.formattedAverageDistance)
            }

            if viewModel.bestMonth?.totalDistanceInKilometers ?? 0 > 0 || viewModel.bestDayByDistance != nil {
                Section("Highlights") {
                    if let best = viewModel.bestMonth, best.totalDistanceInKilometers > 0 {
                        NavigationLink {
                            if let user = userProfile {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            } else {
                                MonthDetailView(userId: viewModel.userId, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Best Month", value: "\(best.shortMonthName) (\(best.formattedTotalDistance))")
                        }
                    }
                    if let mostActive = viewModel.mostActiveMonth, mostActive.runCount > 0 {
                        NavigationLink {
                            if let user = userProfile {
                                MonthDetailView(user: user, year: mostActive.year, month: mostActive.month)
                            } else {
                                MonthDetailView(userId: viewModel.userId, year: mostActive.year, month: mostActive.month)
                            }
                        } label: {
                            LabeledContent("Most Runs Month", value: "\(mostActive.shortMonthName) (\(String(format: String(localized: "%d runs", comment: "Run count"), mostActive.runCount)))")
                        }
                    }
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent {
                                Text("\(best.formattedShortDate) (\(best.formattedDistance))")
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Best Day")
                                    Text("Distance")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if let best = viewModel.bestDayByPace {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent {
                                Text("\(best.formattedShortDate) (\(best.formattedPace))")
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Best Day")
                                    Text("Pace")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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

            if let best = viewModel.bestMonth, stats.month == best.month, best.totalDistanceInKilometers > 0 {
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
