import Foundation

struct RunningRecord: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let distanceInMeters: Double
    let durationInSeconds: TimeInterval
    let caloriesBurned: Double?

    var distanceInKilometers: Double {
        distanceInMeters / 1000.0
    }

    var formattedDistance: String {
        String(format: "%.2f km", distanceInKilometers)
    }

    var formattedDuration: String {
        let hours = Int(durationInSeconds) / 3600
        let minutes = (Int(durationInSeconds) % 3600) / 60
        let seconds = Int(durationInSeconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var averagePacePerKilometer: TimeInterval? {
        guard distanceInKilometers > 0 else { return nil }
        return durationInSeconds / distanceInKilometers
    }

    var formattedPace: String {
        guard let pace = averagePacePerKilometer else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
