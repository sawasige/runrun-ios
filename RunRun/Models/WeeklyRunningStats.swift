import Foundation

struct WeeklyRunningStats: Identifiable {
    let id: UUID
    let weekStartDate: Date
    let totalDistanceInMeters: Double
    let totalDurationInSeconds: TimeInterval
    let runCount: Int

    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        totalDistanceInMeters: Double,
        totalDurationInSeconds: TimeInterval,
        runCount: Int
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.totalDistanceInMeters = totalDistanceInMeters
        self.totalDurationInSeconds = totalDurationInSeconds
        self.runCount = runCount
    }

    var totalDistanceInKilometers: Double {
        totalDistanceInMeters / 1000.0
    }

    var formattedTotalDistance: String {
        String(format: "%.2f km", totalDistanceInKilometers)
    }

    /// 週の期間を表示（例: "12/23 - 12/29"）
    var formattedWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: endDate))"
    }

    /// 週番号を表示（例: "W52"）
    var formattedWeekNumber: String {
        let weekOfYear = Calendar.current.component(.weekOfYear, from: weekStartDate)
        return "W\(weekOfYear)"
    }

    /// 平均ペース（秒/km）
    var averagePacePerKm: TimeInterval? {
        guard totalDistanceInKilometers > 0 else { return nil }
        return totalDurationInSeconds / totalDistanceInKilometers
    }

    var formattedAveragePace: String {
        guard let pace = averagePacePerKm else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
