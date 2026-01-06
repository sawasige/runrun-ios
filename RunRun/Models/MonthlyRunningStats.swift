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

    var averageDistancePerRun: Double {
        guard runCount > 0 else { return 0 }
        return totalDistanceInKilometers / Double(runCount)
    }

    /// Short month name for charts (e.g., "Jan", "1月")
    var shortMonthName: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    /// Year label for picker (e.g., "2026", "2026年")
    static func formattedYear(_ year: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return "\(year)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter.string(from: date)
    }
}
