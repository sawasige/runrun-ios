import Foundation

struct MonthlyRunningStats: Identifiable, Equatable {
    let id: UUID
    let year: Int
    let month: Int
    let totalDistanceInMeters: Double
    let totalDurationInSeconds: TimeInterval
    let runCount: Int

    var totalDistanceInKilometers: Double {
        totalDistanceInMeters / 1000.0
    }

    var formattedTotalDistance: String {
        String(format: "%.2f km", totalDistanceInKilometers)
    }

    var formattedMonth: String {
        "\(year)年\(month)月"
    }

    var averageDistancePerRun: Double {
        guard runCount > 0 else { return 0 }
        return totalDistanceInKilometers / Double(runCount)
    }
}
