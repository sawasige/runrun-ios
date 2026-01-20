import Foundation

struct TimelineRun: Identifiable {
    let id: String
    let date: Date
    let distanceKm: Double
    let durationSeconds: TimeInterval
    let userId: String
    let displayName: String
    let avatarURL: URL?
    let iconName: String

    // 詳細データ
    var caloriesBurned: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?
    var cadence: Double?
    var strideLength: Double?
    var stepCount: Int?

    func formattedDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(distanceKm, useMetric: useMetric)
    }

    var formattedDuration: String {
        let hours = Int(durationSeconds) / 3600
        let minutes = (Int(durationSeconds) % 3600) / 60
        let seconds = Int(durationSeconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    func formattedPace(useMetric: Bool) -> String {
        guard distanceKm > 0 else { return "--:--" }
        let pacePerKm = durationSeconds / distanceKm
        return UnitFormatter.formatPace(secondsPerKm: pacePerKm, useMetric: useMetric)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func toRunningRecord() -> RunningRecord {
        RunningRecord(
            date: date,
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            caloriesBurned: caloriesBurned,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            cadence: cadence,
            strideLength: strideLength,
            stepCount: stepCount
        )
    }

    func toUserProfile() -> UserProfile {
        UserProfile(
            id: userId,
            displayName: displayName,
            email: nil,
            iconName: iconName,
            avatarURL: avatarURL
        )
    }
}

struct TimelineDayGroup: Identifiable {
    let id: Date
    let date: Date
    let runs: [TimelineRun]

    var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMMdE")
            return formatter.string(from: date)
        }
    }
}
