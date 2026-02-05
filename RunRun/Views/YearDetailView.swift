import SwiftUI
import Charts
import FirebaseAuth
import UIKit

struct YearDetailView: View {
    @StateObject private var viewModel: YearDetailViewModel
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.navigationAction) private var navigationAction
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric

    let userProfile: UserProfile
    @State private var showShareSettings = false
    @State private var selectedMonth: Int?
    @State private var tooltipPosition: CGPoint?

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)

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

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var canGoToOldest: Bool {
        guard let oldest = viewModel.oldestYear else { return false }
        return viewModel.selectedYear > oldest
    }

    private func goToOldestYear() {
        guard let oldest = viewModel.oldestYear else { return }
        Task {
            await viewModel.updateYear(to: oldest)
        }
    }

    private func goToPreviousYear() {
        Task {
            await viewModel.updateYear(to: viewModel.selectedYear - 1)
        }
    }

    private func goToNextYear() {
        Task {
            await viewModel.updateYear(to: viewModel.selectedYear + 1)
        }
    }

    private func goToLatestYear() {
        Task {
            await viewModel.updateYear(to: currentYear)
        }
    }

    private var yearNavigationButtons: some View {
        ExpandableNavigationButtons(
            canGoToOldest: canGoToOldest,
            canGoPrevious: canGoToOldest,
            canGoNext: !isCurrentYear,
            canGoToLatest: !isCurrentYear,
            onOldest: goToOldestYear,
            onPrevious: goToPreviousYear,
            onNext: goToNextYear,
            onLatest: goToLatestYear
        )
    }

    var body: some View {
        mainContent
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                if viewModel.monthlyStats.isEmpty && viewModel.error == nil {
                    // スケルトン表示
                    skeletonContent
                } else if let error = viewModel.error {
                    Section {
                        VStack(spacing: 16) {
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    statsContent
                }
            }
            .listStyle(.insetGrouped)

            if !viewModel.isLoading && viewModel.error == nil && !viewModel.monthlyStats.isEmpty {
                yearNavigationButtons
                    .padding()
                    .padding(.bottom, 8)
            }
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
                    NavigationLink(value: ScreenType.profile(userProfile)) {
                        ProfileAvatarView(user: userProfile, size: 28)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSettings) {
            YearShareSettingsView(
                shareData: YearlyShareData(
                    year: String(viewModel.selectedYear),
                    totalDistance: viewModel.formattedTotalYearlyDistance(useMetric: useMetric),
                    runCount: viewModel.totalRunCount,
                    totalDuration: viewModel.formattedTotalDuration,
                    averagePace: viewModel.formattedAveragePace(useMetric: useMetric),
                    averageDistance: viewModel.formattedAverageDistance(useMetric: useMetric),
                    averageDuration: viewModel.formattedAverageDuration,
                    totalCalories: viewModel.formattedTotalCalories,
                    monthlyDistanceData: viewModel.monthlyStats.map { (month: $0.month, distance: $0.totalDistanceInKilometers) }
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
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            if isOwnRecord {
                Task {
                    await viewModel.refresh()
                }
            }
        }
        .onChange(of: viewModel.selectedYear) { _, _ in
            // 年移動時に選択解除
            selectedMonth = nil
            tooltipPosition = nil
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        Section("Monthly Distance") {
                monthlyChart
                    .frame(height: 200)
            }

            Section("Distance Progress") {
                cumulativeChart
                    .frame(height: 200)
            }

            Section("Totals") {
                LabeledContent("Distance") {
                    Text(viewModel.formattedTotalYearlyDistance(useMetric: useMetric))
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
                LabeledContent("Pace", value: viewModel.formattedAveragePace(useMetric: useMetric))
                LabeledContent("Distance/Run", value: viewModel.formattedAverageDistance(useMetric: useMetric))
                LabeledContent("Time/Run", value: viewModel.formattedAverageDuration)
            }

            if viewModel.bestMonthByDistance != nil || viewModel.bestDayByDistance != nil {
                Section("Highlights") {
                    // 月のハイライト
                    if let best = viewModel.bestMonthByDistance {
                        NavigationLink(value: ScreenType.monthDetail(user: userProfile, year: best.year, month: best.month)) {
                            LabeledContent("Best Distance Month", value: "\(best.shortMonthName) (\(best.formattedTotalDistance(useMetric: useMetric)))")
                        }
                    }
                    if let best = viewModel.bestMonthByDuration {
                        NavigationLink(value: ScreenType.monthDetail(user: userProfile, year: best.year, month: best.month)) {
                            LabeledContent("Best Duration Month", value: "\(best.shortMonthName) (\(best.formattedTotalDuration))")
                        }
                    }
                    if let best = viewModel.mostRunsMonth {
                        NavigationLink(value: ScreenType.monthDetail(user: userProfile, year: best.year, month: best.month)) {
                            LabeledContent("Most Runs Month", value: "\(best.shortMonthName) (\(String(format: String(localized: "%d runs", comment: "Run count"), best.runCount)))")
                        }
                    }
                    // 日のハイライト
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                            LabeledContent("Best Distance Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDistance(useMetric: useMetric)))")
                        }
                    }
                    if let best = viewModel.bestDayByDuration {
                        NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                            LabeledContent("Best Duration Day", value: "\(monthDayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = viewModel.fastestDay {
                        NavigationLink(value: ScreenType.runDetail(record: fastest, user: userProfile)) {
                            LabeledContent("Fastest Day", value: "\(monthDayString(from: fastest.date)) (\(fastest.formattedPace(useMetric: useMetric)))")
                        }
                    }
                }
            }

            Section("Monthly Records") {
                ForEach(Array(filteredMonthlyStats.reversed().enumerated()), id: \.element.id) { index, stats in
                    NavigationLink(value: ScreenType.monthDetail(user: userProfile, year: stats.year, month: stats.month)) {
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

    @ViewBuilder
    private var skeletonContent: some View {
        Section("Monthly Distance") {
            SkeletonChart()
                .frame(height: 200)
                .listRowBackground(ShimmerBackground())
        }

        Section("Distance Progress") {
            SkeletonChart()
                .frame(height: 200)
                .listRowBackground(ShimmerBackground())
        }

        Section("Totals") {
            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    SkeletonRect()
                        .frame(width: 80, height: 14)
                    Spacer()
                    SkeletonRect()
                        .frame(width: 60, height: 14)
                }
            }
        }

        Section("Monthly Records") {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonMonthRow()
            }
        }
    }

    private var monthlyChart: some View {
        Chart(viewModel.monthlyStats) { stats in
            BarMark(
                x: .value(String(localized: "Month"), stats.shortMonthName),
                y: .value(String(localized: "Distance"), stats.chartDistance(useMetric: useMetric))
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = viewModel.bestMonthByDistance, stats.month == best.month, best.totalDistanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.chartDistance(useMetric: useMetric)))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartYAxisLabel(UnitFormatter.distanceUnit(useMetric: useMetric))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotFrame = proxy.plotFrame.map { geometry[$0] }
                ZStack(alignment: .topLeading) {
                    // ハイライト矩形
                    if let month = selectedMonth,
                       let stats = viewModel.monthlyStats.first(where: { $0.month == month }),
                       let xPos = proxy.position(forX: stats.shortMonthName),
                       let plotArea = plotFrame {
                        let categoryWidth = plotArea.width / CGFloat(viewModel.monthlyStats.count)
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: categoryWidth, height: plotArea.height)
                            .position(x: xPos, y: plotArea.minY + plotArea.height / 2)
                    }

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            // グラフ領域外のタップは無視
                            if let plotFrame = proxy.plotFrame {
                                let plotArea = geometry[plotFrame]
                                guard plotArea.contains(location) else {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        selectedMonth = nil
                                        tooltipPosition = nil
                                    }
                                    return
                                }
                            }

                            guard let monthName: String = proxy.value(atX: location.x) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                                return
                            }
                            guard let stats = viewModel.monthlyStats.first(where: { $0.shortMonthName == monthName }) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedMonth = stats.month
                                if let xPos = proxy.position(forX: stats.shortMonthName) {
                                    tooltipPosition = CGPoint(x: xPos, y: 8)
                                }
                            }
                            hapticFeedback.impactOccurred()
                        }

                    // ツールチップ表示
                    if let month = selectedMonth,
                       let position = tooltipPosition,
                       let stats = viewModel.monthlyStats.first(where: { $0.month == month }) {
                        let prevStats = viewModel.previousYearMonthlyStats.first(where: { $0.month == month })
                        let canNavigate = canNavigateToMonth(stats: stats)
                        ChartTooltip(
                            title: stats.shortMonthName,
                            value: stats.formattedTotalDistance(useMetric: useMetric),
                            previousValue: prevStats?.formattedTotalDistance(useMetric: useMetric),
                            previousLabel: String(localized: "Prev year"),
                            onTap: canNavigate ? {
                                navigationAction?.append(ScreenType.monthDetail(user: userProfile, year: stats.year, month: stats.month))
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                            } : nil
                        )
                        .id("monthlyChartTooltip")
                        .position(x: position.x, y: position.y)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private func canNavigateToMonth(stats: MonthlyRunningStats) -> Bool {
        // ランがない月は遷移不可
        guard stats.runCount > 0 else { return false }

        // 未来月は遷移不可
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if stats.year > currentYear {
            return false
        } else if stats.year == currentYear && stats.month > currentMonth {
            return false
        }
        return true
    }

    /// 各月の開始日（非閏年）
    private let monthStartDays = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

    private var cumulativeChart: some View {
        Chart {
            // 選択中の月エリアをハイライト
            if let month = selectedMonth {
                let startDay = monthStartDays[month - 1]
                let endDay = month < 12 ? monthStartDays[month] - 1 : 365
                RectangleMark(
                    xStart: .value("Start", startDay),
                    xEnd: .value("End", endDay)
                )
                .foregroundStyle(Color.accentColor.opacity(0.15))
            }

            // 当年の累積距離
            ForEach(viewModel.cumulativeDistanceData, id: \.dayOfYear) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.dayOfYear),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance, useMetric: useMetric)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value(String(localized: "Day"), data.dayOfYear),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance, useMetric: useMetric))
                )
                .foregroundStyle(Color.accentColor.opacity(0.1))
            }

            // 前年の累積距離（比較用）
            ForEach(viewModel.previousYearCumulativeData, id: \.dayOfYear) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.dayOfYear),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.distance, useMetric: useMetric)),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }

            // 当年の場合、最後（今日）に点滅する点を表示
            if isCurrentYear, let lastPoint = viewModel.cumulativeDistanceData.last {
                PointMark(
                    x: .value(String(localized: "Day"), lastPoint.dayOfYear),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(lastPoint.distance, useMetric: useMetric))
                )
                .symbol {
                    PulsingDot()
                }
            }
        }
        .chartXScale(domain: 1...365)
        .chartXAxis {
            AxisMarks(values: [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        let monthIndex = dayOfYearToMonth(day) - 1
                        if monthIndex >= 0, monthIndex < 12 {
                            Text(Calendar.current.shortMonthSymbols[monthIndex])
                        }
                    }
                }
            }
        }
        .chartYAxisLabel(UnitFormatter.distanceUnit(useMetric: useMetric))
        .chartLegend(Visibility.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            // グラフ領域外のタップは無視
                            if let plotFrame = proxy.plotFrame {
                                let plotArea = geometry[plotFrame]
                                guard plotArea.contains(location) else {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        selectedMonth = nil
                                        tooltipPosition = nil
                                    }
                                    return
                                }
                            }

                            guard let dayOfYear: Double = proxy.value(atX: location.x) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                                return
                            }
                            let month = dayOfYearToMonth(Int(dayOfYear))
                            guard viewModel.monthlyStats.contains(where: { $0.month == month }) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedMonth = month
                                // 月の中央位置を計算
                                let startDay = monthStartDays[month - 1]
                                let endDay = month < 12 ? monthStartDays[month] - 1 : 365
                                let midDay = (startDay + endDay) / 2
                                if let xPos = proxy.position(forX: midDay) {
                                    tooltipPosition = CGPoint(x: xPos, y: 8)
                                }
                            }
                            hapticFeedback.impactOccurred()
                        }

                    // ツールチップ表示
                    if let month = selectedMonth,
                       let position = tooltipPosition,
                       let stats = viewModel.monthlyStats.first(where: { $0.month == month }) {
                        let cumulativeDistance = cumulativeDistanceAtEndOfMonth(month)
                        let prevCumulativeDistance = previousYearCumulativeDistanceAtEndOfMonth(month)
                        let canNavigate = canNavigateToMonth(stats: stats)
                        ChartTooltip(
                            title: stats.shortMonthName,
                            value: UnitFormatter.formatDistance(cumulativeDistance, useMetric: useMetric),
                            previousValue: prevCumulativeDistance > 0 ? UnitFormatter.formatDistance(prevCumulativeDistance, useMetric: useMetric) : nil,
                            previousLabel: String(localized: "Prev year"),
                            onTap: canNavigate ? {
                                navigationAction?.append(ScreenType.monthDetail(user: userProfile, year: stats.year, month: stats.month))
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedMonth = nil
                                    tooltipPosition = nil
                                }
                            } : nil
                        )
                        .id("cumulativeChartTooltip")
                        .position(x: position.x, y: position.y)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    /// 指定月末時点の累計距離を取得
    private func cumulativeDistanceAtEndOfMonth(_ month: Int) -> Double {
        let endDay = month < 12 ? monthStartDays[month] - 1 : 365
        // その日以下で最も大きい日のデータを取得
        if let data = viewModel.cumulativeDistanceData.last(where: { $0.dayOfYear <= endDay }) {
            return data.distance
        }
        return 0
    }

    /// 前年同月末時点の累計距離を取得
    private func previousYearCumulativeDistanceAtEndOfMonth(_ month: Int) -> Double {
        let endDay = month < 12 ? monthStartDays[month] - 1 : 365
        if let data = viewModel.previousYearCumulativeData.last(where: { $0.dayOfYear <= endDay }) {
            return data.distance
        }
        return 0
    }

    private func dayOfYearToMonth(_ dayOfYear: Int) -> Int {
        // 各月の開始日（非閏年）
        let monthStartDays = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
        for (index, startDay) in monthStartDays.enumerated().reversed() {
            if dayOfYear >= startDay {
                return index + 1
            }
        }
        return 1
    }
}

struct MonthlyStatsRow: View {
    let stats: MonthlyRunningStats
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric

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

            Text(stats.formattedTotalDistance(useMetric: useMetric))
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
