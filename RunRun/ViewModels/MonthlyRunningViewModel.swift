import Foundation
import Combine

@MainActor
final class MonthlyRunningViewModel: ObservableObject {
    @Published private(set) var monthlyStats: [MonthlyRunningStats] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var selectedYear: Int

    private let healthKitService = HealthKitService()

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
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
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

    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    init() {
        self.selectedYear = Calendar.current.component(.year, from: Date())
    }

    func onAppear() async {
        await requestHealthKitAuthorization()
        await loadMonthlyStats()
    }

    func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            self.error = error
        }
    }

    func loadMonthlyStats() async {
        isLoading = true
        error = nil

        do {
            monthlyStats = try await healthKitService.fetchMonthlyStats(for: selectedYear)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func refresh() async {
        await loadMonthlyStats()
    }
}
