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

    var formattedDistance: String {
        String(format: "%.2f km", distanceKm)
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

    var formattedPace: String {
        guard distanceKm > 0 else { return "--:--" }
        let pace = durationSeconds / distanceKm
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct TimelineDayGroup: Identifiable {
    let id: Date
    let date: Date
    let runs: [TimelineRun]

    var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            formatter.dateFormat = "M月d日 (E)"
            return formatter.string(from: date)
        }
    }
}
