import Foundation
import Combine

@MainActor
final class YearlyRecordsViewModel: ObservableObject {
    @Published private(set) var monthlyStats: [MonthlyRunningStats] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var selectedYear: Int

    let userId: String
    private let firestoreService = FirestoreService.shared

    var totalYearlyDistance: Double {
        monthlyStats.reduce(0) { $0 + $1.totalDistanceInKilometers }
    }

    var formattedTotalYearlyDistance: String {
        String(format: "%.2f km", totalYearlyDistance)
    }

    var totalRunCount: Int {
        monthlyStats.reduce(0) { $0 + $1.runCount }
    }

    var totalDuration: TimeInterval {
        monthlyStats.reduce(0) { $0 + $1.totalDurationInSeconds }
    }

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "%dh %dm", comment: "Duration format"), hours, minutes)
        }
        return String(format: String(localized: "%dm", comment: "Minutes only"), minutes)
    }

    var averageDistancePerRun: Double {
        guard totalRunCount > 0 else { return 0 }
        return totalYearlyDistance / Double(totalRunCount)
    }

    var formattedAverageDistance: String {
        String(format: "%.2f km", averageDistancePerRun)
    }

    var bestMonth: MonthlyRunningStats? {
        monthlyStats.max(by: { $0.totalDistanceInKilometers < $1.totalDistanceInKilometers })
    }

    var mostActiveMonth: MonthlyRunningStats? {
        monthlyStats.filter { $0.runCount > 0 }.max(by: { $0.runCount < $1.runCount })
    }

    var averagePace: TimeInterval? {
        guard totalYearlyDistance > 0 else { return nil }
        return totalDuration / totalYearlyDistance
    }

    var formattedAveragePace: String {
        guard let pace = averagePace else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var totalCalories: Double {
        monthlyStats.reduce(0) { $0 + $1.totalCalories }
    }

    var formattedTotalCalories: String? {
        guard totalCalories > 0 else { return nil }
        return String(format: "%.0f kcal", totalCalories)
    }

    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    init(userId: String, initialYear: Int? = nil) {
        self.userId = userId
        let currentYear = Calendar.current.component(.year, from: Date())
        if let initialYear = initialYear {
            self.selectedYear = initialYear
        } else {
            // スクリーンショットモードでは前年を表示
            self.selectedYear = ScreenshotMode.isEnabled ? currentYear - 1 : currentYear
        }
    }

    func onAppear() async {
        await loadMonthlyStats()
    }

    func loadMonthlyStats() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            monthlyStats = MockDataProvider.monthlyStats.filter { $0.year == selectedYear }
            isLoading = false
            return
        }

        // データがない場合のみローディング表示（チラつき防止）
        if monthlyStats.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            let runs = try await firestoreService.getUserRuns(userId: userId)
            monthlyStats = aggregateToMonthlyStats(runs: runs, for: selectedYear)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func refresh() async {
        await loadMonthlyStats()
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
