import Foundation

struct YearlyStats: Identifiable, Equatable {
    let id: UUID
    let year: Int
    let totalDistanceInMeters: Double
    let totalDurationInSeconds: TimeInterval
    let runCount: Int

    var totalDistanceInKilometers: Double {
        totalDistanceInMeters / 1000.0
    }

    var formattedTotalDistance: String {
        String(format: "%.1f km", totalDistanceInKilometers)
    }

    var formattedYear: String {
        MonthlyRunningStats.formattedYear(year)
    }

    var shortFormattedYear: String {
        String(format: "'%02d", year % 100)
    }

    var averageDistancePerRun: Double {
        guard runCount > 0 else { return 0 }
        return totalDistanceInKilometers / Double(runCount)
    }

    var averagePace: TimeInterval? {
        guard totalDistanceInKilometers > 0 else { return nil }
        return totalDurationInSeconds / totalDistanceInKilometers
    }
}
