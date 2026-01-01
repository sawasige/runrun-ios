import Foundation

struct Split: Identifiable {
    let id: Int
    let kilometer: Int
    let durationSeconds: TimeInterval
    let distanceMeters: Double

    init(kilometer: Int, durationSeconds: TimeInterval, distanceMeters: Double) {
        self.id = kilometer
        self.kilometer = kilometer
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }

    /// ペース（秒/km）
    var pacePerKm: TimeInterval {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1000)
    }

    /// フォーマット済みペース（例: "5:30"）
    var formattedPace: String {
        let pace = pacePerKm
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// フォーマット済みキロ表示（例: "1 km" or "5 km (端数)"）
    var formattedKilometer: String {
        if distanceMeters >= 950 && distanceMeters <= 1050 {
            return "\(kilometer) km"
        } else {
            let km = distanceMeters / 1000
            return String(format: "%.2f km", km)
        }
    }
}
