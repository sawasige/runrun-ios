import SwiftUI
import Charts
import FirebaseAuth

struct YearDetailView: View {
    @StateObject private var viewModel: YearDetailViewModel
    @EnvironmentObject private var syncService: SyncService

    let userProfile: UserProfile
    @State private var showShareSettings = false

    private var isOwnRecord: Bool {
        if ScreenshotMode.isEnabled {
            return userProfile.id == MockDataProvider.currentUserId
        }
        return userProfile.id == Auth.auth().currentUser?.uid
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

    private var isCurrentYear: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return viewModel.selectedYear == currentYear
    }

    private func goToPreviousYear() {
        viewModel.selectedYear -= 1
    }

    private func goToNextYear() {
        viewModel.selectedYear += 1
    }

    private var yearNavigationButtons: some View {
        HStack(spacing: 0) {
            Button {
                goToPreviousYear()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }

            Divider()
                .frame(height: 30)

            Button {
                goToNextYear()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }
            .disabled(isCurrentYear)
            .opacity(isCurrentYear ? 0.3 : 1)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    var body: some View {
        Group {
            if isOwnRecord {
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
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else {
                    statsListView
                }
            }

            // フローティング年切り替えボタン
            yearNavigationButtons
                .padding()
                .padding(.bottom, 8)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if isOwnRecord {
                        Button {
                            showShareSettings = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    NavigationLink {
                        ProfileView(user: userProfile)
                    } label: {
                        ProfileAvatarView(user: userProfile, size: 28)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSettings) {
            YearShareSettingsView(
                shareData: YearlyShareData(
                    year: String(viewModel.selectedYear),
                    totalDistance: viewModel.formattedTotalYearlyDistance,
                    runCount: viewModel.totalRunCount,
                    totalDuration: viewModel.formattedTotalDuration,
                    averagePace: viewModel.formattedAveragePace,
                    averageDistance: viewModel.formattedAverageDistance,
                    averageDuration: viewModel.formattedAverageDuration,
                    totalCalories: viewModel.formattedTotalCalories
                ),
                isOwnData: isOwnRecord,
                isPresented: $showShareSettings
            )
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
            if isOwnRecord {
                Task {
                    await viewModel.refresh()
                }
            }
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statsListView: some View {
        List {
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
                if isOwnRecord, let calories = viewModel.formattedTotalCalories {
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
                            MonthDetailView(user: userProfile, year: best.year, month: best.month)
                        } label: {
                            LabeledContent("Best Distance Month", value: "\(best.shortMonthName) (\(best.formattedTotalDistance))")
                        }
                    }
                    if let best = viewModel.bestMonthByDuration {
                        NavigationLink {
                            MonthDetailView(user: userProfile, year: best.year, month: best.month)
                        } label: {
                            LabeledContent("Best Duration Month", value: "\(best.shortMonthName) (\(best.formattedTotalDuration))")
                        }
                    }
                    if let best = viewModel.mostRunsMonth {
                        NavigationLink {
                            MonthDetailView(user: userProfile, year: best.year, month: best.month)
                        } label: {
                            LabeledContent("Most Runs Month", value: "\(best.shortMonthName) (\(String(format: String(localized: "%d runs", comment: "Run count"), best.runCount)))")
                        }
                    }
                    // 日のハイライト
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink {
                            RunDetailView(record: best, user: userProfile)
                        } label: {
                            LabeledContent("Best Distance Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDistance))")
                        }
                    }
                    if let best = viewModel.bestDayByDuration {
                        NavigationLink {
                            RunDetailView(record: best, user: userProfile)
                        } label: {
                            LabeledContent("Best Duration Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = viewModel.fastestDay {
                        NavigationLink {
                            RunDetailView(record: fastest, user: userProfile)
                        } label: {
                            LabeledContent("Fastest Day", value: "\(monthDayString(from: fastest.date)) (\(fastest.formattedPace))")
                        }
                    }
                }
            }

            Section("Monthly Records") {
                ForEach(Array(filteredMonthlyStats.reversed().enumerated()), id: \.element.id) { index, stats in
                    NavigationLink {
                        MonthDetailView(user: userProfile, year: stats.year, month: stats.month)
                    } label: {
                        MonthlyStatsRow(stats: stats)
                            .accessibilityIdentifier(index == 0 ? "first_month_row" : "month_row_\(index)")
                    }
                }
            }

            // フローティングボタン分の余白
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
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
        .chartYAxisLabel(UnitFormatter.distanceUnit)
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
    YearDetailView(user: UserProfile(id: "preview", displayName: "Preview User", email: nil, iconName: "figure.run"))
}
