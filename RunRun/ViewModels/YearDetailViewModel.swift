import Foundation
import Combine

@MainActor
final class YearDetailViewModel: ObservableObject {
    @Published private(set) var monthlyStats: [MonthlyRunningStats] = []
    @Published private(set) var previousYearMonthlyStats: [MonthlyRunningStats] = []
    @Published private(set) var yearlyRuns: [RunningRecord] = []
    @Published private(set) var previousYearRuns: [RunningRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var selectedYear: Int
    @Published private(set) var oldestYear: Int?
    @Published private(set) var yearlyGoal: RunningGoal?

    let userId: String
    private let firestoreService = FirestoreService.shared

    var totalYearlyDistance: Double {
        monthlyStats.reduce(0) { $0 + $1.totalDistanceInKilometers }
    }

    func formattedTotalYearlyDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(totalYearlyDistance, useMetric: useMetric)
    }

    var totalRunCount: Int {
        monthlyStats.reduce(0) { $0 + $1.runCount }
    }

    var totalDuration: TimeInterval {
        monthlyStats.reduce(0) { $0 + $1.totalDurationInSeconds }
    }

    var formattedTotalDuration: String {
        UnitFormatter.formatDuration(totalDuration)
    }

    var averageDistancePerRun: Double {
        guard totalRunCount > 0 else { return 0 }
        return totalYearlyDistance / Double(totalRunCount)
    }

    func formattedAverageDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(averageDistancePerRun, useMetric: useMetric)
    }

    var averageDurationPerRun: TimeInterval {
        guard totalRunCount > 0 else { return 0 }
        return totalDuration / Double(totalRunCount)
    }

    var formattedAverageDuration: String {
        UnitFormatter.formatDuration(averageDurationPerRun)
    }

    // MARK: - ハイライト（月）

    /// 最長距離月
    var bestMonthByDistance: MonthlyRunningStats? {
        monthlyStats.filter { $0.totalDistanceInKilometers > 0 }.max(by: { $0.totalDistanceInKilometers < $1.totalDistanceInKilometers })
    }

    /// 最長時間月
    var bestMonthByDuration: MonthlyRunningStats? {
        monthlyStats.filter { $0.totalDurationInSeconds > 0 }.max(by: { $0.totalDurationInSeconds < $1.totalDurationInSeconds })
    }

    /// 最多回数月
    var mostRunsMonth: MonthlyRunningStats? {
        monthlyStats.filter { $0.runCount > 0 }.max(by: { $0.runCount < $1.runCount })
    }

    var averagePace: TimeInterval? {
        guard totalYearlyDistance > 0 else { return nil }
        return totalDuration / totalYearlyDistance
    }

    func formattedAveragePace(useMetric: Bool) -> String {
        UnitFormatter.formatPace(secondsPerKm: averagePace, useMetric: useMetric)
    }

    var totalCalories: Double {
        monthlyStats.reduce(0) { $0 + $1.totalCalories }
    }

    var formattedTotalCalories: String? {
        UnitFormatter.formatCalories(totalCalories)
    }

    // MARK: - ハイライト（日）

    /// 最長距離日
    var bestDayByDistance: RunningRecord? {
        yearlyRuns.max { $0.distanceInKilometers < $1.distanceInKilometers }
    }

    /// 最長時間日
    var bestDayByDuration: RunningRecord? {
        yearlyRuns.max { $0.durationInSeconds < $1.durationInSeconds }
    }

    /// 最速日 - ペースは小さいほど速い
    var fastestDay: RunningRecord? {
        yearlyRuns.filter { $0.averagePacePerKilometer != nil && $0.distanceInKilometers >= 1.0 }
            .min { ($0.averagePacePerKilometer ?? .infinity) < ($1.averagePacePerKilometer ?? .infinity) }
    }

    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    // MARK: - 累積距離データ（日単位）

    /// 累積距離データ（当年）- 日単位
    var cumulativeDistanceData: [(dayOfYear: Int, distance: Double)] {
        buildDailyCumulativeData(from: yearlyRuns, year: selectedYear)
    }

    /// 累積距離データ（前年）- 日単位
    var previousYearCumulativeData: [(dayOfYear: Int, distance: Double)] {
        buildDailyCumulativeData(from: previousYearRuns, year: selectedYear - 1)
    }

    private func buildDailyCumulativeData(from runs: [RunningRecord], year: Int) -> [(dayOfYear: Int, distance: Double)] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1

        // 当年の場合は今日まで、過去年の場合は年末まで
        // スクリーンショットモードでは8月末（243日目）まで表示
        let maxDay: Int
        if ScreenshotMode.isEnabled && year == currentYear {
            maxDay = 243 // 8月末
        } else if year < currentYear {
            maxDay = 365
        } else {
            maxDay = currentDayOfYear
        }

        // 日別に距離を合算
        var dailyDistances: [Int: Double] = [:]
        for run in runs {
            if let dayOfYear = calendar.ordinality(of: .day, in: .year, for: run.date) {
                dailyDistances[dayOfYear, default: 0] += run.distanceInKilometers
            }
        }

        // 累積距離を計算（全ての日を含める）
        var result: [(dayOfYear: Int, distance: Double)] = []
        var cumulative: Double = 0

        for day in 1...maxDay {
            cumulative += dailyDistances[day] ?? 0
            result.append((day, cumulative))
        }

        return result
    }

    init(userId: String, initialYear: Int? = nil) {
        self.userId = userId
        let currentYear = Calendar.current.component(.year, from: Date())
        if let initialYear = initialYear {
            self.selectedYear = initialYear
        } else {
            self.selectedYear = currentYear
        }
    }

    func onAppear() async {
        await updateYear(to: selectedYear)
    }

    func updateYear(to year: Int) async {
        // デバッグ用遅延
        await DebugSettings.applyLoadDelay()

        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            selectedYear = year
            monthlyStats = MockDataProvider.monthlyStats.filter { $0.year == year }
            previousYearMonthlyStats = MockDataProvider.monthlyStats.filter { $0.year == year - 1 }
            yearlyRuns = MockDataProvider.yearDetailRecords
            previousYearRuns = MockDataProvider.previousYearDetailRecords
            yearlyGoal = MockDataProvider.yearlyGoal
            isLoading = false
            return
        }

        // データがない場合のみローディング表示（チラつき防止）
        if monthlyStats.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            // 先にデータを取得
            async let runsTask = firestoreService.getUserRuns(userId: userId)
            async let yearlyRunsTask = firestoreService.getUserYearlyRuns(userId: userId, year: year)
            async let prevYearRunsTask = firestoreService.getUserYearlyRuns(userId: userId, year: year - 1)
            async let oldestRunTask = firestoreService.getOldestRun(userId: userId)

            let runs = try await runsTask
            let newMonthlyStats = aggregateToMonthlyStats(runs: runs, for: year)
            let newPrevYearStats = aggregateToMonthlyStats(runs: runs, for: year - 1)
            let newYearlyRuns = try await yearlyRunsTask
            let newPrevYearRuns = try await prevYearRunsTask
            let oldestRun = try await oldestRunTask

            // 全て取得してから一括更新
            selectedYear = year
            monthlyStats = newMonthlyStats
            previousYearMonthlyStats = newPrevYearStats
            yearlyRuns = newYearlyRuns
            previousYearRuns = newPrevYearRuns

            if let oldestRun = oldestRun {
                oldestYear = Calendar.current.component(.year, from: oldestRun.date)
            }

            // 目標は別途取得（エラーが発生しても他のデータは表示する）
            do {
                yearlyGoal = try await firestoreService.getYearlyGoal(userId: userId, year: year)
            } catch {
                print("Failed to fetch yearly goal: \(error)")
                yearlyGoal = nil
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func refresh() async {
        await updateYear(to: selectedYear)
    }

    func saveGoal(_ goal: RunningGoal) async {
        do {
            let savedGoal = try await firestoreService.setGoal(userId: userId, goal: goal)
            yearlyGoal = savedGoal
            AnalyticsService.logEvent("set_goal", parameters: [
                "type": goal.type.rawValue,
                "target_km": goal.targetDistanceKm
            ])
        } catch {
            print("Failed to save goal: \(error)")
        }
    }

    func deleteGoal() async {
        guard let goalId = yearlyGoal?.id else { return }
        do {
            try await firestoreService.deleteGoal(userId: userId, goalId: goalId)
            yearlyGoal = nil
            AnalyticsService.logEvent("delete_goal", parameters: [
                "type": "yearly"
            ])
        } catch {
            print("Failed to delete goal: \(error)")
        }
    }

    func getDefaultYearlyDistance() async -> Double? {
        do {
            let latestGoal = try await firestoreService.getLatestYearlyGoal(userId: userId)
            return latestGoal?.targetDistanceKm
        } catch {
            return nil
        }
    }

    private func aggregateToMonthlyStats(
        runs: [(date: Date, distanceKm: Double, durationSeconds: TimeInterval, caloriesBurned: Double?)],
        for year: Int
    ) -> [MonthlyRunningStats] {
        let calendar = Calendar.current

        // Filter runs for the selected year
        let yearRuns = runs.filter { calendar.component(.year, from: $0.date) == year }

        // Group by month
        var monthlyData: [Int: (distance: Double, duration: TimeInterval, count: Int, calories: Double)] = [:]

        for run in yearRuns {
            let month = calendar.component(.month, from: run.date)
            let current = monthlyData[month] ?? (0, 0, 0, 0)
            monthlyData[month] = (
                current.distance + run.distanceKm,
                current.duration + run.durationSeconds,
                current.count + 1,
                current.calories + (run.caloriesBurned ?? 0)
            )
        }

        // Create stats for all 12 months
        var stats: [MonthlyRunningStats] = []
        for month in 1...12 {
            let data = monthlyData[month] ?? (0, 0, 0, 0)
            stats.append(MonthlyRunningStats(
                id: UUID(),
                year: year,
                month: month,
                totalDistanceInMeters: data.distance * 1000,
                totalDurationInSeconds: data.duration,
                runCount: data.count,
                totalCalories: data.calories
            ))
        }

        return stats
    }
}
