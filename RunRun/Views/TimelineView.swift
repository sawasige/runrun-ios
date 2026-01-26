import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @EnvironmentObject private var syncService: SyncService
    @AppStorage("units.distance") private var useMetricUnits = UnitFormatter.defaultUseMetric
    @State private var showNavBarLogo = false
    @State private var monthlyDistance: Double = 0
    @State private var monthlyRunCount: Int = 0
    @State private var monthlyRecords: [RunningRecord] = []

    let userProfile: UserProfile

    private let firestoreService = FirestoreService.shared

    private var currentMonthLabel: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: now)
    }

    init(userId: String, userProfile: UserProfile) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(userId: userId))
        self.userProfile = userProfile
    }

    private var contentState: Int {
        if viewModel.isLoading && viewModel.runs.isEmpty { return 0 }
        if viewModel.error != nil && viewModel.runs.isEmpty { return 1 }
        if viewModel.runs.isEmpty { return 2 }
        return 3
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.runs.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.runs.isEmpty {
                errorView(error: error)
            } else if viewModel.runs.isEmpty {
                emptyView
            } else {
                timelineList
            }
        }
        .animation(.easeInOut(duration: 0.4), value: contentState)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                    Text("RunRun")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .opacity(showNavBarLogo ? 1 : 0)
                .blur(radius: showNavBarLogo ? 0 : 8)
                .offset(y: showNavBarLogo ? 0 : 16)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: ScreenType.profile(userProfile)) {
                    ProfileAvatarView(user: userProfile, size: 28)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
            await loadMonthlySummary()
        }
        .task {
            await viewModel.onAppear()
            await loadMonthlySummary()
        }
        .onAppear {
            AnalyticsService.logScreenView("Timeline")
        }
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            Task {
                await viewModel.refresh()
                await loadMonthlySummary()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileDidUpdate)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }

    private var expandedHeaderView: some View {
        VStack(spacing: 16) {
            // 上部中央: ロゴとタイトル（横並び）
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)

                Text("RunRun")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .opacity(showNavBarLogo ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                            let threshold: CGFloat = 100
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showNavBarLogo = newValue < threshold
                            }
                        }
                }
            )

            // 今月のサマリ（タップで月詳細へ）
            NavigationLink(value: ScreenType.monthDetail(
                user: userProfile,
                year: Calendar.current.component(.year, from: Date()),
                month: Calendar.current.component(.month, from: Date())
            )) {
                monthSummaryStats
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timeline_month_summary")

        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }

    private var monthSummaryStats: some View {
        VStack(spacing: 8) {
            // 上部: 月ラベルとシェブロン
            HStack {
                Text(currentMonthLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // 中央: ミニカレンダー
            MiniCalendarView(records: monthlyRecords)

            Divider()

            // 下部: 距離と回数
            HStack(spacing: 0) {
                // 距離
                VStack(spacing: 2) {
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(UnitFormatter.formatDistanceValue(monthlyDistance, useMetric: useMetricUnits, decimals: 1))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text(UnitFormatter.distanceUnit(useMetric: useMetricUnits))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 回数
                VStack(spacing: 2) {
                    Text("Runs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(monthlyRunCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("runs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadMonthlySummary() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            monthlyDistance = 68.5
            monthlyRunCount = 12
            monthlyRecords = MockDataProvider.monthDetailRecords
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            let runs = try await firestoreService.getUserMonthlyRuns(
                userId: viewModel.userId,
                year: year,
                month: month
            )

            monthlyDistance = runs.reduce(0) { $0 + $1.distanceInKilometers }
            monthlyRunCount = runs.count
            monthlyRecords = runs
        } catch {
            print("Failed to load monthly summary: \(error)")
        }
    }

    private var loadingView: some View {
        ShineLogoView(size: 80)
            .frame(width: 80, height: 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No records yet",
            systemImage: "figure.run",
            description: Text("Your and your friends' running records will appear here")
        )
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
                .textSelection(.enabled)
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

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                expandedHeaderView

                ForEach(viewModel.dayGroups) { group in
                    sectionHeader(title: group.formattedDate)

                    ForEach(group.runs) { run in
                        let isOwn = run.userId == viewModel.userId
                        let profile = isOwn ? userProfile : run.toUserProfile()
                        NavigationLink(value: ScreenType.runDetail(record: run.toRunningRecord(), user: profile)) {
                            TimelineRunRow(run: run)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.hasMore {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

private struct TimelineRunRow: View {
    let run: TimelineRun
    @AppStorage("units.distance") private var useMetricUnits = UnitFormatter.defaultUseMetric

    private var paceSecondsPerKm: Double? {
        guard run.distanceKm > 0 else { return nil }
        return run.durationSeconds / run.distanceKm
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(iconName: run.iconName, avatarURL: run.avatarURL, size: 40)

            // 左側: 名前と時間・ペース
            VStack(alignment: .leading, spacing: 2) {
                Text(run.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                // 時間とペース（控えめに）
                HStack(spacing: 6) {
                    Text(run.formattedDuration)
                    Text("·")
                    Text(UnitFormatter.formatPaceValue(secondsPerKm: paceSecondsPerKm, useMetric: useMetricUnits))
                    Text(UnitFormatter.paceUnit(useMetric: useMetricUnits))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // 右側: 距離（ヒーロー表示）
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(UnitFormatter.formatDistanceValue(run.distanceKm, useMetric: useMetricUnits, decimals: 2))
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text(UnitFormatter.distanceUnit(useMetric: useMetricUnits))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

/// タイムライン用のミニカレンダー（今月のランを小さく表示）
private struct MiniCalendarView: View {
    let records: [RunningRecord]

    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 20

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var year: Int {
        calendar.component(.year, from: Date())
    }

    private var month: Int {
        calendar.component(.month, from: Date())
    }

    private var weekdaySymbols: [String] {
        calendar.veryShortStandaloneWeekdaySymbols
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // ロケールの週開始日を考慮してオフセットを計算
        let offset = weekday - calendar.firstWeekday
        return offset >= 0 ? offset : offset + 7
    }

    private var runDays: Set<Int> {
        var days = Set<Int>()
        for record in records {
            let day = calendar.component(.day, from: record.date)
            days.insert(day)
        }
        return days
    }

    private var today: Int? {
        // スクリーンショットモードでは今日の表示をしない
        guard !ScreenshotMode.isEnabled else { return nil }
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        // 今月の場合のみ今日の日付を返す
        guard year == currentYear && month == currentMonth else { return nil }
        return calendar.component(.day, from: now)
    }

    var body: some View {
        VStack(spacing: 4) {
            // 曜日ヘッダー
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption2)
                        .foregroundStyle(weekdayHeaderColor(index: index))
                }
            }

            // 日付グリッド
            LazyVGrid(columns: columns, spacing: 2) {
                // 月初の空白
                ForEach(0..<firstWeekdayOffset, id: \.self) { index in
                    Color.clear
                        .frame(height: cellHeight)
                        .id("empty-\(index)")
                }

                // 日付
                ForEach(Array(1...daysInMonth), id: \.self) { day in
                    dayCell(day: day)
                        .id("day-\(day)")
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let hasRun = runDays.contains(day)
        let isToday = day == today
        let weekday = weekdayForDay(day)

        Text("\(day)")
            .font(.caption.weight(hasRun ? .bold : .regular))
            .foregroundStyle(dayTextColor(weekday: weekday, hasRun: hasRun, isToday: isToday))
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
            .background {
                if hasRun {
                    Circle().fill(Color.accentColor)
                } else if isToday {
                    Circle().stroke(Color.accentColor, lineWidth: 1)
                }
            }
    }

    private func weekdayForDay(_ day: Int) -> Int {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.component(.weekday, from: date) - 1 // 0=日, 6=土
    }

    private func weekdayHeaderColor(index: Int) -> Color {
        // veryShortStandaloneWeekdaySymbolsはロケールの週開始日から始まる
        // 日本では月曜始まり: [月,火,水,木,金,土,日]
        // 米国では日曜始まり: [日,月,火,水,木,金,土]
        let firstWeekdayIndex = calendar.firstWeekday - 1 // 0-indexed
        let actualWeekday = (index + firstWeekdayIndex) % 7
        switch actualWeekday {
        case 0: return .red   // 日曜
        case 6: return .blue  // 土曜
        default: return .secondary
        }
    }

    private func dayTextColor(weekday: Int, hasRun: Bool, isToday: Bool) -> Color {
        if hasRun {
            return .white
        }
        if isToday {
            return .accentColor
        }
        switch weekday {
        case 0: return .red   // 日曜
        case 6: return .blue  // 土曜
        default: return .primary
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView(userId: "preview", userProfile: UserProfile(id: "preview", displayName: "Preview User", email: nil, iconName: "figure.run"))
            .navigationDestination(for: ScreenType.self) { _ in
                EmptyView()
            }
    }
}
