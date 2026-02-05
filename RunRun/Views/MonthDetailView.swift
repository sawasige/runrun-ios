import SwiftUI
import Charts
import FirebaseAuth
import UIKit

struct MonthDetailView: View {
    @StateObject private var viewModel: MonthDetailViewModel
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.navigationAction) private var navigationAction
    let userProfile: UserProfile
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric
    @State private var currentYear: Int
    @State private var currentMonth: Int
    @State private var hasLoadedOnce = false
    @State private var showShareSettings = false
    @State private var showNavBarTitle = false

    // チャートタップ状態
    @State private var selectedDay: Int?
    @State private var draggingDay: Int?
    @State private var tooltipPosition: CGPoint?
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)

    /// 現在ハイライトすべき日（ドラッグ中 or 選択中）
    private var highlightedDay: Int? {
        draggingDay ?? selectedDay
    }

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

    private var formattedYear: String {
        String(format: String(localized: "%d year_suffix", comment: "Year format e.g. 2026年"), currentYear)
    }

    private var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        guard let date = Calendar.current.date(from: DateComponents(year: currentYear, month: currentMonth)) else {
            return ""
        }
        return formatter.string(from: date)
    }

    private func dayString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: String(localized: "%d day_suffix", comment: "Day format e.g. 15日"), day)
    }

    private var canGoToOldest: Bool {
        guard let oldestYear = viewModel.oldestYear, let oldestMonth = viewModel.oldestMonth else { return false }
        return currentYear > oldestYear || (currentYear == oldestYear && currentMonth > oldestMonth)
    }

    private func goToOldestMonth() {
        guard let oldestYear = viewModel.oldestYear, let oldestMonth = viewModel.oldestMonth else { return }
        currentYear = oldestYear
        currentMonth = oldestMonth
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

    private func goToLatestMonth() {
        let now = Date()
        let calendar = Calendar.current
        currentYear = calendar.component(.year, from: now)
        currentMonth = calendar.component(.month, from: now)
    }

    /// 現在の月の日曜日の日付（Date）を返す
    private var sundayDatesInMonth: [Date] {
        let calendar = Calendar.current
        var sundays: [Date] = []
        guard let startOfMonth = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        for day in range {
            if let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)),
               calendar.component(.weekday, from: date) == 1 { // 1 = 日曜日
                sundays.append(date)
            }
        }
        return sundays
    }

    /// 現在の月の日曜日の日（Int）を返す
    private var sundayDaysInMonth: [Int] {
        let calendar = Calendar.current
        var sundays: [Int] = []
        guard let startOfMonth = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        for day in range {
            if let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)),
               calendar.component(.weekday, from: date) == 1 { // 1 = 日曜日
                sundays.append(day)
            }
        }
        return sundays
    }

    /// 指定日にランがあるかどうか
    private func canNavigateToDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        return viewModel.records.contains { record in
            let recordDay = calendar.component(.day, from: record.date)
            return recordDay == day
        }
    }

    /// 指定日のランレコードを取得
    private func recordForDay(_ day: Int) -> RunningRecord? {
        let calendar = Calendar.current
        return viewModel.records.first { record in
            let recordDay = calendar.component(.day, from: record.date)
            return recordDay == day
        }
    }

    /// 指定日の距離を取得（km）
    private func distanceForDay(_ day: Int) -> Double {
        if let record = recordForDay(day) {
            return record.distanceInKilometers
        }
        return 0
    }

    /// 指定日末時点の累計距離を取得（km）
    private func cumulativeDistanceAtDay(_ day: Int) -> Double {
        if let data = viewModel.cumulativeDistanceData.last(where: { $0.day <= day }) {
            return data.distance
        }
        return 0
    }

    /// 前月同日末時点の累計距離を取得（km）
    private func previousMonthCumulativeDistanceAtDay(_ day: Int) -> Double {
        if let data = viewModel.previousMonthCumulativeData.last(where: { $0.day <= day }) {
            return data.distance
        }
        return 0
    }

    /// 日付から「◯日」の文字列を取得
    private func dayLabel(_ day: Int) -> String {
        String(format: String(localized: "%d day_suffix", comment: "Day format e.g. 15日"), day)
    }

    /// 現在の月の日数を取得
    private var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    /// 指定日が現在の月に存在するかどうか
    private func isValidDay(_ day: Int) -> Bool {
        day >= 1 && day <= daysInCurrentMonth
    }

    /// 累積距離データを展開（日の領域内で斜めに上昇するように）
    private var expandedCumulativeData: [(x: Double, y: Double)] {
        // 当月の場合は今日まで、過去月の場合は月末まで
        let maxDay: Int
        if isCurrentMonth {
            maxDay = Calendar.current.component(.day, from: Date())
        } else {
            maxDay = daysInCurrentMonth
        }
        return expandCumulativeData(viewModel.cumulativeDistanceData, extendToDay: maxDay)
    }

    /// 前月累積距離データを展開
    private var expandedPreviousMonthData: [(x: Double, y: Double)] {
        // 前月の日数を計算
        let calendar = Calendar.current
        var prevYear = currentYear
        var prevMonth = currentMonth - 1
        if prevMonth < 1 {
            prevMonth = 12
            prevYear -= 1
        }
        let prevMonthDays: Int
        if let date = calendar.date(from: DateComponents(year: prevYear, month: prevMonth)),
           let range = calendar.range(of: .day, in: .month, for: date) {
            prevMonthDays = range.count
        } else {
            prevMonthDays = 31
        }
        return expandCumulativeData(viewModel.previousMonthCumulativeData, extendToDay: prevMonthDays)
    }

    /// 累積データを展開して、各日の領域内で斜めに上昇するデータポイントを生成
    private func expandCumulativeData(_ data: [(day: Int, distance: Double)], extendToDay: Int) -> [(x: Double, y: Double)] {
        guard !data.isEmpty else { return [] }

        var result: [(x: Double, y: Double)] = []
        var previousDistance: Double = 0

        for (index, point) in data.enumerated() {
            let day = Double(point.day)

            if index == 0 {
                // 最初のポイント: 日の開始位置
                result.append((x: day, y: previousDistance))
            } else {
                // 日の開始位置（前の累積値）
                result.append((x: day, y: previousDistance))
            }

            // 日の終了位置（新しい累積値）
            result.append((x: day + 0.9, y: point.distance))

            previousDistance = point.distance
        }

        // 月末まで線を延長
        if let lastPoint = data.last, lastPoint.day < extendToDay {
            result.append((x: Double(extendToDay) + 0.9, y: previousDistance))
        }

        return result
    }

    private var dateHeaderView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // 年
            Button {
                navigationAction?.append(.yearDetail(user: userProfile, initialYear: currentYear))
            } label: {
                Text(formattedYear)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.forward")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // 月
            Text(formattedMonth)
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()
        }
        .padding(.horizontal, 20)
        .opacity(showNavBarTitle ? 0 : 1)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global).maxY) { _, newValue in
                        let threshold: CGFloat = 100
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showNavBarTitle = newValue < threshold
                        }
                    }
            }
        )
    }

    private var monthNavigationButtons: some View {
        ExpandableNavigationButtons(
            canGoToOldest: canGoToOldest,
            canGoPrevious: canGoToOldest,
            canGoNext: !isCurrentMonth,
            canGoToLatest: !isCurrentMonth,
            onOldest: goToOldestMonth,
            onPrevious: goToPreviousMonth,
            onNext: goToNextMonth,
            onLatest: goToLatestMonth
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let error = viewModel.error {
                    errorView(error: error)
                } else if hasLoadedOnce && viewModel.records.isEmpty {
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
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen("MonthDetail")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.title)
                    .font(.headline)
                    .opacity(showNavBarTitle ? 1 : 0)
                    .blur(radius: showNavBarTitle ? 0 : 8)
                    .offset(y: showNavBarTitle ? 0 : 16)
            }
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
                    totalDistance: viewModel.formattedTotalDistance(useMetric: useMetric),
                    runCount: viewModel.runCount,
                    totalDuration: viewModel.formattedTotalDuration,
                    averagePace: viewModel.formattedAveragePace(useMetric: useMetric),
                    averageDistance: viewModel.formattedAverageDistance(useMetric: useMetric),
                    averageDuration: viewModel.formattedAverageDuration,
                    totalCalories: viewModel.formattedTotalCalories,
                    cumulativeData: viewModel.cumulativeDistanceData
                ),
                isOwnData: isOwnRecord,
                isPresented: $showShareSettings
            )
        }
        .task {
            await viewModel.onAppear()
            hasLoadedOnce = true
        }
        .onChange(of: [currentYear, currentMonth]) { _, _ in
            // 月移動時に選択解除
            selectedDay = nil
            tooltipPosition = nil
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
            // 日付ヘッダー
            dateHeaderView
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !hasLoadedOnce && viewModel.records.isEmpty {
                // スケルトン表示
                skeletonContent
            } else {
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
                        Text(viewModel.formattedTotalDistance(useMetric: useMetric))
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
                    LabeledContent("Pace", value: viewModel.formattedAveragePace(useMetric: useMetric))
                    LabeledContent("Distance/Run", value: viewModel.formattedAverageDistance(useMetric: useMetric))
                    LabeledContent("Time/Run", value: viewModel.formattedAverageDuration)
                }

                if viewModel.bestDayByDistance != nil || viewModel.bestDayByDuration != nil || viewModel.fastestDay != nil {
                    Section("Highlights") {
                        if let best = viewModel.bestDayByDistance {
                            NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                                LabeledContent("Best Distance Day", value: "\(dayString(from: best.date)) (\(best.formattedDistance(useMetric: useMetric)))")
                            }
                        }
                        if let best = viewModel.bestDayByDuration {
                            NavigationLink(value: ScreenType.runDetail(record: best, user: userProfile)) {
                                LabeledContent("Best Duration Day", value: "\(dayString(from: best.date)) (\(best.formattedDuration))")
                            }
                        }
                        if let fastest = viewModel.fastestDay {
                            NavigationLink(value: ScreenType.runDetail(record: fastest, user: userProfile)) {
                                LabeledContent("Fastest Day", value: "\(dayString(from: fastest.date)) (\(fastest.formattedPace(useMetric: useMetric)))")
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
            }

            // フローティングボタン分の余白
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
        }
        .contentMargins(.top, 0)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, _ in
            if selectedDay != nil {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedDay = nil
                    tooltipPosition = nil
                }
            }
        }
    }

    @ViewBuilder
    private var skeletonContent: some View {
        // カレンダー
        Section {
            SkeletonCalendar(year: currentYear, month: currentMonth)
                .listRowBackground(ShimmerBackground())
        }

        // グラフ
        Section("Daily Distance") {
            SkeletonChart()
                .frame(height: 150)
                .listRowBackground(ShimmerBackground())
        }

        Section("Distance Progress") {
            SkeletonChart()
                .frame(height: 150)
                .listRowBackground(ShimmerBackground())
        }

        // 統計
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

        // ラン記録
        Section("Running Records") {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonRunRow()
            }
        }
    }

    private var dailyChart: some View {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: viewModel.year, month: viewModel.month, day: 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(day: 31), to: startOfMonth)!

        return Chart {
            // タップ中または選択中の日エリアをハイライト
            if let day = highlightedDay,
               let startDate = calendar.date(from: DateComponents(year: viewModel.year, month: viewModel.month, day: day)),
               let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) {
                RectangleMark(
                    xStart: .value("Start", startDate),
                    xEnd: .value("End", endDate)
                )
                .foregroundStyle(Color.accentColor.opacity(0.15))
            }

            ForEach(viewModel.records) { record in
                BarMark(
                    x: .value(String(localized: "Day"), record.date, unit: .day),
                    y: .value(String(localized: "Distance"), record.chartDistance(useMetric: useMetric))
                )
                .foregroundStyle(Color.accentColor.gradient)
            }

            if let best = viewModel.bestDayByDistance, best.distanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.chartDistance(useMetric: useMetric)))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartXScale(domain: startOfMonth...endOfMonth)
        .chartXAxis {
            AxisMarks(values: sundayDatesInMonth) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxisLabel(useMetric ? "km" : "mi", position: .top)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let calendar = Calendar.current
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            // グラフ領域外のタップは無視
                            if let plotFrame = proxy.plotFrame {
                                let plotArea = geometry[plotFrame]
                                guard plotArea.contains(location) else {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        selectedDay = nil
                                        tooltipPosition = nil
                                    }
                                    return
                                }
                            }

                            guard let date: Date = proxy.value(atX: location.x) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            // 表示月内の日付かチェック
                            let dateYear = calendar.component(.year, from: date)
                            let dateMonth = calendar.component(.month, from: date)
                            guard dateYear == viewModel.year && dateMonth == viewModel.month else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            let day = calendar.component(.day, from: date)
                            guard isValidDay(day) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedDay = day
                                if let dayDate = calendar.date(from: DateComponents(year: viewModel.year, month: viewModel.month, day: day)),
                                   let xPos = proxy.position(forX: dayDate) {
                                    tooltipPosition = CGPoint(x: xPos, y: 8)
                                }
                            }
                            hapticFeedback.impactOccurred()
                        }

                    // ツールチップ表示
                    if let day = selectedDay,
                       let position = tooltipPosition {
                        let distance = distanceForDay(day)
                        let hasRun = canNavigateToDay(day)
                        ChartTooltip(
                            title: dayLabel(day),
                            value: UnitFormatter.formatDistance(distance, useMetric: useMetric),
                            onTap: hasRun ? {
                                if let record = recordForDay(day) {
                                    navigationAction?.append(ScreenType.runDetail(record: record, user: userProfile))
                                }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                            } : nil
                        )
                        .id("dailyChartTooltip")
                        .position(x: position.x, y: position.y)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private var cumulativeChart: some View {
        Chart {
            // タップ中または選択中の日エリアをハイライト
            if let day = highlightedDay {
                RectangleMark(
                    xStart: .value("Start", day),
                    xEnd: .value("End", day + 1)
                )
                .foregroundStyle(Color.accentColor.opacity(0.15))
            }

            // 当月の累積距離
            ForEach(expandedCumulativeData, id: \.x) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.x),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.y, useMetric: useMetric)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value(String(localized: "Day"), data.x),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.y, useMetric: useMetric))
                )
                .foregroundStyle(Color.accentColor.opacity(0.1))
            }

            // 前月の累積距離（比較用）
            ForEach(expandedPreviousMonthData, id: \.x) { data in
                LineMark(
                    x: .value(String(localized: "Day"), data.x),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(data.y, useMetric: useMetric)),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }

            // 当月の場合、最後（今日）に点滅する点を表示
            if isCurrentMonth, let lastPoint = expandedCumulativeData.last {
                PointMark(
                    x: .value(String(localized: "Day"), lastPoint.x),
                    y: .value(String(localized: "Distance"), UnitFormatter.convertDistance(lastPoint.y, useMetric: useMetric))
                )
                .symbol {
                    PulsingDot()
                }
            }
        }
        .chartXScale(domain: 1...32)
        .chartXAxis {
            AxisMarks(values: sundayDaysInMonth) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let day = value.as(Int.self),
                       let date = Calendar.current.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) {
                        Text(date, format: .dateTime.day())
                    }
                }
            }
        }
        .chartYAxisLabel(useMetric ? "km" : "mi", position: .top)
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
                                        selectedDay = nil
                                        tooltipPosition = nil
                                    }
                                    return
                                }
                            }

                            guard let dayValue: Double = proxy.value(atX: location.x) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                                return
                            }
                            let day = max(1, min(31, Int(dayValue)))

                            guard isValidDay(day) else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
                                    tooltipPosition = nil
                                }
                                return
                            }

                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedDay = day
                                // 日の中央に配置（day + 0.5）
                                if let xPos = proxy.position(forX: Double(day) + 0.5) {
                                    tooltipPosition = CGPoint(x: xPos, y: 8)
                                }
                            }
                            hapticFeedback.impactOccurred()
                        }

                    // ツールチップ表示
                    if let day = selectedDay,
                       let position = tooltipPosition {
                        let cumulativeDistance = cumulativeDistanceAtDay(day)
                        let prevCumulativeDistance = previousMonthCumulativeDistanceAtDay(day)
                        let hasRun = canNavigateToDay(day)
                        ChartTooltip(
                            title: dayLabel(day),
                            value: UnitFormatter.formatDistance(cumulativeDistance, useMetric: useMetric),
                            previousValue: prevCumulativeDistance > 0 ? UnitFormatter.formatDistance(prevCumulativeDistance, useMetric: useMetric) : nil,
                            previousLabel: String(localized: "Prev month"),
                            onTap: hasRun ? {
                                if let record = recordForDay(day) {
                                    navigationAction?.append(ScreenType.runDetail(record: record, user: userProfile))
                                }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedDay = nil
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
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric

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
                Text(record.formattedDistance(useMetric: useMetric))
                    .font(.headline)
            }

            HStack(spacing: 16) {
                Label(record.formattedDuration, systemImage: "clock")
                Label(record.formattedPace(useMetric: useMetric), systemImage: "speedometer")
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
