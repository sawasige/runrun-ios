import SwiftUI
import FirebaseAuth
import Charts

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthenticationService
    let user: UserProfile

    @State private var isFriend = false
    @State private var isLoading = true
    @State private var isProcessing = false
    @State private var canSendRequest = true
    @State private var lastRequestDate: Date?
    @State private var showingProfileEdit = false
    @State private var currentProfile: UserProfile?

    // 統計データ
    @State private var yearlyStats: [YearlyStats] = []
    @State private var monthlyStats: [MonthlyRunningStats] = []
    @State private var allRuns: [RunningRecord] = []
    @State private var totalDistance: Double = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var totalRuns: Int = 0
    @State private var totalCalories: Double = 0

    private let firestoreService = FirestoreService.shared

    private var isCurrentUser: Bool {
        user.id == authService.user?.uid
    }

    private var displayedProfile: UserProfile {
        currentProfile ?? user
    }

    // 効率
    private var averagePace: TimeInterval? {
        guard totalDistance > 0 else { return nil }
        return totalDuration / totalDistance
    }

    private var formattedAveragePace: String {
        guard let pace = averagePace else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private var averageDistancePerRun: Double {
        guard totalRuns > 0 else { return 0 }
        return totalDistance / Double(totalRuns)
    }

    private var formattedAverageDistance: String {
        String(format: "%.2f km", averageDistancePerRun)
    }

    private var averageDurationPerRun: TimeInterval {
        guard totalRuns > 0 else { return 0 }
        return totalDuration / Double(totalRuns)
    }

    private var formattedAverageDuration: String {
        let duration = averageDurationPerRun
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "%dh %dm", comment: "Duration format"), hours, minutes)
        }
        return String(format: String(localized: "%dm", comment: "Minutes only"), minutes)
    }

    private var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "%dh %dm", comment: "Duration format"), hours, minutes)
        }
        return String(format: String(localized: "%dm", comment: "Minutes only"), minutes)
    }

    private var formattedTotalCalories: String? {
        guard totalCalories > 0 else { return nil }
        return String(format: "%.0f kcal", totalCalories)
    }

    // MARK: - ハイライト（年）

    /// 最長距離年
    private var bestYearByDistance: YearlyStats? {
        yearlyStats.filter { $0.runCount > 0 }.max { $0.totalDistanceInKilometers < $1.totalDistanceInKilometers }
    }

    /// 最長時間年
    private var bestYearByDuration: YearlyStats? {
        yearlyStats.filter { $0.runCount > 0 }.max { $0.totalDurationInSeconds < $1.totalDurationInSeconds }
    }

    /// 最多回数年
    private var mostRunsYear: YearlyStats? {
        yearlyStats.filter { $0.runCount > 0 }.max { $0.runCount < $1.runCount }
    }

    // MARK: - ハイライト（月）

    /// 最長距離月
    private var bestMonthByDistance: MonthlyRunningStats? {
        monthlyStats.filter { $0.runCount > 0 }.max { $0.totalDistanceInKilometers < $1.totalDistanceInKilometers }
    }

    /// 最長時間月
    private var bestMonthByDuration: MonthlyRunningStats? {
        monthlyStats.filter { $0.runCount > 0 }.max { $0.totalDurationInSeconds < $1.totalDurationInSeconds }
    }

    /// 最多回数月
    private var mostRunsMonth: MonthlyRunningStats? {
        monthlyStats.filter { $0.runCount > 0 }.max { $0.runCount < $1.runCount }
    }

    // MARK: - ハイライト（日）

    /// 最長距離日
    private var bestDayByDistance: RunningRecord? {
        allRuns.max { $0.distanceInKilometers < $1.distanceInKilometers }
    }

    /// 最長時間日
    private var bestDayByDuration: RunningRecord? {
        allRuns.max { $0.durationInSeconds < $1.durationInSeconds }
    }

    /// 最速日 - ペースは小さいほど速い
    private var fastestDay: RunningRecord? {
        allRuns.filter { $0.averagePacePerKilometer != nil && $0.distanceInKilometers >= 1.0 }
            .min { ($0.averagePacePerKilometer ?? .infinity) < ($1.averagePacePerKilometer ?? .infinity) }
    }

    private func yearMonthDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: date)
    }

    var body: some View {
        List {
            // プロフィールヘッダー
            Section {
                VStack(spacing: 16) {
                    ProfileAvatarView(user: displayedProfile, size: 100)

                    Text(displayedProfile.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // 年別グラフ
            if !yearlyStats.isEmpty {
                Section("Yearly Distance") {
                    yearlyChart
                        .frame(height: 200)
                }
            }

            // 合計
            Section("Totals") {
                LabeledContent("Distance") {
                    Text(String(format: "%.1f km", totalDistance))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                LabeledContent("Time", value: formattedTotalDuration)
                LabeledContent("Count", value: String(format: String(localized: "%d runs", comment: "Run count"), totalRuns))
                if isCurrentUser, let calories = formattedTotalCalories {
                    LabeledContent("Energy", value: calories)
                }
            }

            // 平均
            Section("Averages") {
                LabeledContent("Pace", value: formattedAveragePace)
                LabeledContent("Distance/Run", value: formattedAverageDistance)
                LabeledContent("Time/Run", value: formattedAverageDuration)
            }

            // ハイライト
            if bestYearByDistance != nil || bestMonthByDistance != nil || bestDayByDistance != nil {
                Section("Highlights") {
                    // 年のハイライト
                    if let best = bestYearByDistance {
                        NavigationLink {
                            if isCurrentUser {
                                YearDetailView(userId: user.id ?? "", initialYear: best.year)
                            } else {
                                YearDetailView(user: user, initialYear: best.year)
                            }
                        } label: {
                            LabeledContent("Best Distance Year", value: "\(best.formattedYear) (\(best.formattedTotalDistance))")
                        }
                    }
                    if let best = bestYearByDuration {
                        NavigationLink {
                            if isCurrentUser {
                                YearDetailView(userId: user.id ?? "", initialYear: best.year)
                            } else {
                                YearDetailView(user: user, initialYear: best.year)
                            }
                        } label: {
                            LabeledContent("Best Duration Year", value: "\(best.formattedYear) (\(best.formattedTotalDuration))")
                        }
                    }
                    if let best = mostRunsYear {
                        NavigationLink {
                            if isCurrentUser {
                                YearDetailView(userId: user.id ?? "", initialYear: best.year)
                            } else {
                                YearDetailView(user: user, initialYear: best.year)
                            }
                        } label: {
                            LabeledContent("Most Runs Year", value: "\(best.formattedYear) (\(String(format: String(localized: "%d runs", comment: "Run count"), best.runCount)))")
                        }
                    }
                    // 月のハイライト
                    if let best = bestMonthByDistance {
                        NavigationLink {
                            if isCurrentUser {
                                MonthDetailView(userId: user.id ?? "", year: best.year, month: best.month)
                            } else {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Best Distance Month", value: "\(best.formattedMonth) (\(best.formattedTotalDistance))")
                        }
                    }
                    if let best = bestMonthByDuration {
                        NavigationLink {
                            if isCurrentUser {
                                MonthDetailView(userId: user.id ?? "", year: best.year, month: best.month)
                            } else {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Best Duration Month", value: "\(best.formattedMonth) (\(best.formattedTotalDuration))")
                        }
                    }
                    if let best = mostRunsMonth {
                        NavigationLink {
                            if isCurrentUser {
                                MonthDetailView(userId: user.id ?? "", year: best.year, month: best.month)
                            } else {
                                MonthDetailView(user: user, year: best.year, month: best.month)
                            }
                        } label: {
                            LabeledContent("Most Runs Month", value: "\(best.formattedMonth) (\(String(format: String(localized: "%d runs", comment: "Run count"), best.runCount)))")
                        }
                    }
                    // 日のハイライト
                    if let best = bestDayByDistance {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: isCurrentUser,
                                userProfile: isCurrentUser ? nil : user,
                                userId: user.id
                            )
                        } label: {
                            LabeledContent("Best Distance Day", value: "\(yearMonthDayString(from: best.date)) (\(best.formattedDistance))")
                        }
                    }
                    if let best = bestDayByDuration {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: isCurrentUser,
                                userProfile: isCurrentUser ? nil : user,
                                userId: user.id
                            )
                        } label: {
                            LabeledContent("Best Duration Day", value: "\(yearMonthDayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = fastestDay {
                        NavigationLink {
                            RunDetailView(
                                record: fastest,
                                isOwnRecord: isCurrentUser,
                                userProfile: isCurrentUser ? nil : user,
                                userId: user.id
                            )
                        } label: {
                            LabeledContent("Fastest Day", value: "\(yearMonthDayString(from: fastest.date)) (\(fastest.formattedPace))")
                        }
                    }
                }
            }

            // 週間推移
            Section("Weekly Trends") {
                NavigationLink {
                    WeeklyStatsView(userId: user.id, userProfile: isCurrentUser ? nil : user)
                } label: {
                    Label("Last 12 Weeks", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            // 年別記録
            if !yearlyStats.isEmpty {
                Section("Yearly Records") {
                    ForEach(yearlyStats.filter { $0.runCount > 0 }.sorted { $0.year > $1.year }) { stats in
                        NavigationLink {
                            if isCurrentUser, let userId = user.id {
                                YearDetailView(userId: userId, initialYear: stats.year)
                            } else {
                                YearDetailView(user: user, initialYear: stats.year)
                            }
                        } label: {
                            YearlyStatsRow(stats: stats)
                        }
                    }
                }
            }

            // フレンド操作
            if !isCurrentUser {
                friendSection
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .analyticsScreen("Profile")
        .toolbar {
            if isCurrentUser {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingProfileEdit = true
                    } label: {
                        Text("Edit", comment: "Edit profile button")
                    }
                }
            }
        }
        .sheet(isPresented: $showingProfileEdit, onDismiss: {
            Task { await reloadProfile() }
        }) {
            if let userId = user.id {
                ProfileEditView(
                    userId: userId,
                    currentDisplayName: displayedProfile.displayName,
                    currentIcon: displayedProfile.iconName,
                    currentAvatarURL: displayedProfile.avatarURL
                )
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Views

    private var yearlyChart: some View {
        Chart(yearlyStats.suffix(12).sorted { $0.year < $1.year }) { stats in
            BarMark(
                x: .value(String(localized: "Year"), stats.shortFormattedYear),
                y: .value(String(localized: "Distance"), stats.totalDistanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = bestYearByDistance, stats.year == best.year, best.totalDistanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.totalDistanceInKilometers))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartYAxisLabel("km")
    }

    @ViewBuilder
    private var friendSection: some View {
        Section {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if isFriend {
                Button(role: .destructive) {
                    Task { await removeFriend() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                        }
                        Spacer()
                    }
                }
                .disabled(isProcessing)
            } else if canSendRequest {
                Button {
                    Task { await sendFriendRequest() }
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                        } else {
                            Label("Send Friend Request", systemImage: "person.badge.plus")
                        }
                        Spacer()
                    }
                }
                .disabled(isProcessing)
            } else {
                VStack(spacing: 4) {
                    Text("Request Sent")
                        .foregroundStyle(.secondary)
                    if let lastDate = lastRequestDate {
                        Text(remainingTimeText(from: lastDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let currentUserId = authService.user?.uid,
              let userId = user.id else { return }

        // データがある場合はローディング表示しない（チラつき防止）
        if yearlyStats.isEmpty {
            isLoading = true
        }

        do {
            // フレンド状態を確認
            if !isCurrentUser {
                isFriend = try await firestoreService.isFriend(
                    currentUserId: currentUserId,
                    otherUserId: userId
                )

                // フレンド申請可能かチェック
                if !isFriend {
                    canSendRequest = try await firestoreService.canSendFriendRequest(
                        fromUserId: currentUserId,
                        toUserId: userId
                    )
                    if !canSendRequest {
                        lastRequestDate = try await firestoreService.getLastFriendRequestDate(
                            fromUserId: currentUserId,
                            toUserId: userId
                        )
                    }
                }
            }

            // 統計を取得
            async let runsTask = firestoreService.getUserRuns(userId: userId)
            async let allRunsTask = firestoreService.getAllUserRunRecords(userId: userId)

            let runs = try await runsTask
            allRuns = try await allRunsTask

            // 全体の統計
            totalDistance = runs.reduce(0) { $0 + $1.distanceKm }
            totalDuration = runs.reduce(0) { $0 + $1.durationSeconds }
            totalRuns = runs.count
            totalCalories = runs.compactMap { $0.caloriesBurned }.reduce(0, +)

            // 月別統計を集計
            monthlyStats = aggregateToMonthlyStats(runs: runs)

            // 年別統計を集計
            yearlyStats = aggregateToYearlyStats(runs: runs)
        } catch {
            print("Load error: \(error)")
        }

        isLoading = false
    }

    private func reloadProfile() async {
        guard let userId = user.id else { return }
        do {
            currentProfile = try await firestoreService.getUserProfile(userId: userId)
        } catch {
            print("Reload profile error: \(error)")
        }
    }

    private func aggregateToYearlyStats(runs: [(date: Date, distanceKm: Double, durationSeconds: TimeInterval, caloriesBurned: Double?)]) -> [YearlyStats] {
        let calendar = Calendar.current

        // Group by year
        var yearlyData: [Int: (distance: Double, duration: TimeInterval, count: Int)] = [:]

        for run in runs {
            let year = calendar.component(.year, from: run.date)
            let current = yearlyData[year] ?? (0, 0, 0)
            yearlyData[year] = (
                current.distance + run.distanceKm,
                current.duration + run.durationSeconds,
                current.count + 1
            )
        }

        // Create stats
        return yearlyData.map { year, data in
            YearlyStats(
                id: UUID(),
                year: year,
                totalDistanceInMeters: data.distance * 1000,
                totalDurationInSeconds: data.duration,
                runCount: data.count
            )
        }
    }

    private func aggregateToMonthlyStats(runs: [(date: Date, distanceKm: Double, durationSeconds: TimeInterval, caloriesBurned: Double?)]) -> [MonthlyRunningStats] {
        let calendar = Calendar.current

        // Group by year-month
        var monthlyData: [String: (year: Int, month: Int, distance: Double, duration: TimeInterval, count: Int, calories: Double)] = [:]

        for run in runs {
            let year = calendar.component(.year, from: run.date)
            let month = calendar.component(.month, from: run.date)
            let key = "\(year)-\(month)"
            let current = monthlyData[key] ?? (year, month, 0, 0, 0, 0)
            monthlyData[key] = (
                year,
                month,
                current.distance + run.distanceKm,
                current.duration + run.durationSeconds,
                current.count + 1,
                current.calories + (run.caloriesBurned ?? 0)
            )
        }

        return monthlyData.values.map { data in
            MonthlyRunningStats(
                id: UUID(),
                year: data.year,
                month: data.month,
                totalDistanceInMeters: data.distance * 1000,
                totalDurationInSeconds: data.duration,
                runCount: data.count,
                totalCalories: data.calories
            )
        }
    }

    // MARK: - Helper Functions

    private func remainingTimeText(from date: Date) -> String {
        let endDate = date.addingTimeInterval(24 * 60 * 60)
        let remaining = endDate.timeIntervalSince(Date())

        if remaining <= 0 {
            return String(localized: "Can request again soon")
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return String(format: String(localized: "Can request again in %dh %dm", comment: "Remaining time with hours"), hours, minutes)
        } else {
            return String(format: String(localized: "Can request again in %dm", comment: "Remaining time minutes only"), minutes)
        }
    }

    private func sendFriendRequest() async {
        guard let currentUserId = authService.user?.uid,
              let toUserId = user.id else { return }

        isProcessing = true

        do {
            let profile = try await firestoreService.getUserProfile(userId: currentUserId)
            try await firestoreService.sendFriendRequest(
                fromUserId: currentUserId,
                fromDisplayName: profile?.displayName ?? String(localized: "User"),
                toUserId: toUserId
            )
            canSendRequest = false
            lastRequestDate = Date()
        } catch {
            print("Send request error: \(error)")
        }

        isProcessing = false
    }

    private func removeFriend() async {
        guard let currentUserId = authService.user?.uid,
              let friendUserId = user.id else { return }

        isProcessing = true

        do {
            try await firestoreService.removeFriend(
                currentUserId: currentUserId,
                friendUserId: friendUserId
            )
            isFriend = false
        } catch {
            print("Remove friend error: \(error)")
        }

        isProcessing = false
    }
}

// MARK: - Supporting Views

private struct YearlyStatsRow: View {
    let stats: YearlyStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.formattedYear)
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
    NavigationStack {
        ProfileView(user: UserProfile(
            id: "test",
            displayName: "Test User",
            email: nil,
            iconName: "figure.run"
        ))
    }
    .environmentObject(AuthenticationService())
}
