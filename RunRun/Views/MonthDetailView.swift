import SwiftUI
import Charts
import FirebaseAuth

struct MonthDetailView: View {
    @StateObject private var viewModel: MonthDetailViewModel
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.navigationAction) private var navigationAction
    let userProfile: UserProfile
    @State private var currentYear: Int
    @State private var currentMonth: Int
    @State private var hasLoadedOnce = false
    @State private var showShareSettings = false

    private var isOwnRecord: Bool {
        if ScreenshotMode.isEnabled {
            return userProfile.id == MockDataProvider.currentUserId
        }
        return userProfile.id == Auth.auth().currentUser?.uid
    }

    init(user: UserProfile, year: Int, month: Int) {
        self.userProfile = user
        _currentYear = State(initialValue: year)
        _currentMonth = State(initialValue: month)
        _viewModel = StateObject(wrappedValue: MonthDetailViewModel(userId: user.id ?? "", year: year, month: month))
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        let calendar = Calendar.current
        return currentYear == calendar.component(.year, from: now) &&
               currentMonth == calendar.component(.month, from: now)
    }

    private func dayString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: String(localized: "%d day_suffix", comment: "Day format e.g. 15日"), day)
    }

    private func goToPreviousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }

    private func goToNextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }

    private var monthNavigationButtons: some View {
        HStack(spacing: 0) {
            Button {
                goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }

            Divider()
                .frame(height: 30)

            Button {
                goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading && !hasLoadedOnce {
                    ProgressView()
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else if viewModel.records.isEmpty {
                    emptyView
                } else {
                    recordsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // フローティング月切り替えボタン
            monthNavigationButtons
                .padding()
                .padding(.bottom, 8)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .analyticsScreen("MonthDetail")
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
                    NavigationLink(value: ScreenType.profile(userProfile)) {
                        ProfileAvatarView(user: userProfile, size: 28)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSettings) {
            MonthShareSettingsView(
                shareData: MonthlyShareData(
                    period: viewModel.title,
                    totalDistance: viewModel.formattedTotalDistance,
                    runCount: viewModel.runCount,
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
            hasLoadedOnce = true
        }
        .onChange(of: currentYear) { _, _ in
            Task {
                await viewModel.updateMonth(year: currentYear, month: currentMonth)
            }
        }
        .onChange(of: currentMonth) { _, _ in
            Task {
                await viewModel.updateMonth(year: currentYear, month: currentMonth)
            }
        }
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            // 自分のデータの場合のみリロード
            if isOwnRecord {
                Task {
                    await viewModel.updateMonth(year: currentYear, month: currentMonth)
                }
            }
        }
    }

    private var recordsList: some View {
        List {
            // カレンダー
            Section {
                RunCalendarView(
                    year: viewModel.year,
                    month: viewModel.month,
                    records: viewModel.records
                ) { record in
                    navigationAction?.append(.runDetail(record: record, user: userProfile))
                }
            }

            // 日別グラフ
            Section("Daily Distance") {
                dailyChart
                    .frame(height: 150)
            }

            // 累積距離グラフ
            Section("Distance Progress") {
                cumulativeChart
                    .frame(height: 150)
            }

            Section("Totals") {
                LabeledContent("Distance") {
                    Text(viewModel.formattedTotalDistance)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                LabeledContent("Time", value: viewModel.formattedTotalDuration)
                LabeledContent("Count", value: String(format: String(localized: "%d runs", comment: "Run count"), viewModel.runCount))
                if isOwnRecord, let calories = viewModel.formattedTotalCalories {
                    LabeledContent("Energy", value: calories)
                }
            }

            Section("Averages") {
                LabeledContent("Pace", value: viewModel.formattedAveragePace)
                LabeledContent("Distance/Run", value: viewModel.formattedAverageDistance)
                LabeledContent("Time/Run", value: viewModel.formattedAverageDuration)
            }

            if viewModel.bestDayByDistance != nil || viewModel.bestDayByDuration != nil || viewModel.fastestDay != nil {
                Section("Highlights") {
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                            LabeledContent("Best Distance Day", value: "\(dayString(from: best.date)) (\(best.formattedDistance))")
                        }
                    }
                    if let best = viewModel.bestDayByDuration {
                        NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                            LabeledContent("Best Duration Day", value: "\(dayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = viewModel.fastestDay {
                        NavigationLink(value: ScreenType.runDetail(record: fastest, user: userProfile)) {
                            LabeledContent("Fastest Day", value: "\(dayString(from: fastest.date)) (\(fastest.formattedPace))")
                        }
                    }
                }
            }

            Section("Running Records") {
                ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                    NavigationLink(value: ScreenType.runDetail(record: record, user: userProfile)) {
                        RunningRecordRow(record: record)
                    }
                    .accessibilityIdentifier(index == 0 ? "first_run_row" : "run_row_\(index)")
                }
            }

            // フローティングボタン分の余白
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var dailyChart: some View {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: viewModel.year, month: viewModel.month, day: 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(day: 31), to: startOfMonth)! // 常に31日分表示（バーが見切れないよう1日余裕）

        return Chart(viewModel.records) { record in
            BarMark(
                x: .value(String(localized: "Day"), record.date, unit: .day),
                y: .value(String(localized: "Distance"), record.chartDistance)
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = viewModel.bestDayByDistance, calendar.isDate(record.date, inSameDayAs: best.date), best.distanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.chartDistance))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartXScale(domain: startOfMonth...endOfMonth)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxisLabel(UnitFormatter.distanceUnit)
    }

    private var cumulativeChart: some View {
        Chart {
            // 当月の累積距離
            ForEach(viewModel.cumulativeDistanceData, id: \.day) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.day),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value(String(localized: "Day"), data.day),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance))
                )
                .foregroundStyle(Color.accentColor.opacity(0.1))
            }

            // 前月の累積距離（比較用）
            ForEach(viewModel.previousMonthCumulativeData, id: \.day) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.day),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance)),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
        }
        .chartXScale(domain: 1...31)
        .chartXAxis {
            AxisMarks(values: .stride(by: 7)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxisLabel(UnitFormatter.distanceUnit)
        .chartLegend(Visibility.hidden)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No running records for this month")
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
        }
        .padding()
    }
}

struct RunningRecordRow: View {
    let record: RunningRecord

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MdEEE")
        return formatter.string(from: record.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.formattedDistance)
                    .font(.headline)
            }

            HStack(spacing: 16) {
                Label(record.formattedDuration, systemImage: "clock")
                Label(record.formattedPace, systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MonthDetailView(user: UserProfile(id: "preview", displayName: "Preview User", email: nil, iconName: "figure.run"), year: 2025, month: 1)
    }
}
