import Foundation
import Combine

@MainActor
final class MonthDetailViewModel: ObservableObject {
    @Published private(set) var records: [RunningRecord] = []
    @Published private(set) var previousMonthRecords: [RunningRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var year: Int
    @Published private(set) var month: Int

    let userId: String

    private let firestoreService = FirestoreService.shared

    var title: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return "\(year)/\(month)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceInKilometers }
    }

    func formattedTotalDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(totalDistance, useMetric: useMetric)
    }

    var totalCalories: Double {
        records.compactMap { $0.caloriesBurned }.reduce(0, +)
    }

    var formattedTotalCalories: String? {
        UnitFormatter.formatCalories(totalCalories)
    }

    var totalDuration: TimeInterval {
        records.reduce(0) { $0 + $1.durationInSeconds }
    }

    var formattedTotalDuration: String {
        UnitFormatter.formatDuration(totalDuration)
    }

    var runCount: Int {
        records.count
    }

    var averagePace: TimeInterval? {
        guard totalDistance > 0 else { return nil }
        return totalDuration / totalDistance
    }

    func formattedAveragePace(useMetric: Bool) -> String {
        UnitFormatter.formatPace(secondsPerKm: averagePace, useMetric: useMetric)
    }

    var averageDistancePerRun: Double {
        guard runCount > 0 else { return 0 }
        return totalDistance / Double(runCount)
    }

    func formattedAverageDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(averageDistancePerRun, useMetric: useMetric)
    }

    var averageDurationPerRun: TimeInterval {
        guard runCount > 0 else { return 0 }
        return totalDuration / Double(runCount)
    }

    var formattedAverageDuration: String {
        UnitFormatter.formatDuration(averageDurationPerRun)
    }

    // MARK: - ハイライト

    /// 最長距離日
    var bestDayByDistance: RunningRecord? {
        records.max { $0.distanceInKilometers < $1.distanceInKilometers }
    }

    /// 最長時間日
    var bestDayByDuration: RunningRecord? {
        records.max { $0.durationInSeconds < $1.durationInSeconds }
    }

    /// 最速日 - ペースは小さいほど速い
    var fastestDay: RunningRecord? {
        records.filter { $0.averagePacePerKilometer != nil && $0.distanceInKilometers >= 1.0 }
            .min { ($0.averagePacePerKilometer ?? .infinity) < ($1.averagePacePerKilometer ?? .infinity) }
    }

    init(userId: String, year: Int, month: Int) {
        self.userId = userId
        self.year = year
        self.month = month
    }

    func onAppear() async {
        await loadRecords()
    }

    func updateMonth(year: Int, month: Int) async {
        self.year = year
        self.month = month
        await loadRecords()
    }

    func loadRecords() async {
        // スクリーンショットモードならモックデータを使用
        if ScreenshotMode.isEnabled {
            records = MockDataProvider.monthDetailRecords
            previousMonthRecords = MockDataProvider.previousMonthDetailRecords
            isLoading = false
            return
        }

        // データがない場合のみローディング表示（チラつき防止）
        if records.isEmpty {
            isLoading = true
        }
        error = nil

        // 前月の年月を計算
        let (prevYear, prevMonth) = previousYearMonth

        do {
            async let currentRecords = firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            async let prevRecords = firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: prevYear,
                month: prevMonth
            )

            records = try await currentRecords
            previousMonthRecords = try await prevRecords
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private var previousYearMonth: (year: Int, month: Int) {
        if month == 1 {
            return (year - 1, 12)
        } else {
            return (year, month - 1)
        }
    }

    /// 累積距離データ（当月）
    var cumulativeDistanceData: [(day: Int, distance: Double)] {
        buildCumulativeData(from: records, year: year, month: month)
    }

    /// 累積距離データ（前月）
    var previousMonthCumulativeData: [(day: Int, distance: Double)] {
        let (prevYear, prevMonth) = previousYearMonth
        return buildCumulativeData(from: previousMonthRecords, year: prevYear, month: prevMonth)
    }

    private func buildCumulativeData(from records: [RunningRecord], year: Int, month: Int) -> [(day: Int, distance: Double)] {
        let calendar = Calendar.current
        var result: [(day: Int, distance: Double)] = []

        // 日別に距離を合算
        var dailyDistances: [Int: Double] = [:]
        for record in records {
            let day = calendar.component(.day, from: record.date)
            dailyDistances[day, default: 0] += record.distanceInKilometers
        }

        // 対象月の最終日を決定
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let currentDay = calendar.component(.day, from: now)

        let maxDay: Int
        if year == currentYear && month == currentMonth {
            // 当月の場合は今日まで
            maxDay = currentDay
        } else {
            // 過去月の場合は月末まで
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            if let firstDayOfMonth = calendar.date(from: components),
               let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) {
                maxDay = range.count
            } else {
                maxDay = 31
            }
        }

        // 累積距離を計算（全ての日を含める）
        var cumulative: Double = 0
        for day in 1...maxDay {
            cumulative += dailyDistances[day] ?? 0
            result.append((day, cumulative))
        }

        return result
    }
}
