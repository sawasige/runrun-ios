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

    /// チャート用距離（ユーザー設定の単位で）
    func chartDistance(useMetric: Bool) -> Double {
        if useMetric {
            return totalDistanceInKilometers
        } else {
            return totalDistanceInKilometers * UnitFormatter.kmToMiles
        }
    }

    func formattedTotalDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(totalDistanceInKilometers, useMetric: useMetric, decimals: 1)
    }

    var formattedTotalDuration: String {
        UnitFormatter.formatDuration(totalDurationInSeconds)
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
