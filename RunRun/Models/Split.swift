import Foundation

struct Split: Identifiable {
    let id: Int
    let kilometer: Int
    let durationSeconds: TimeInterval
    let distanceMeters: Double

    // 時間範囲（心拍数マッチング用）
    var startTime: Date?
    var endTime: Date?

    // 心拍数データ
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?

    init(
        kilometer: Int,
        durationSeconds: TimeInterval,
        distanceMeters: Double,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = kilometer
        self.kilometer = kilometer
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.startTime = startTime
        self.endTime = endTime
    }

    /// ペース（秒/km）
    var pacePerKm: TimeInterval {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1000)
    }

    /// フォーマット済みペース（例: "5:30"）
    var formattedPace: String {
        UnitFormatter.formatPaceValue(secondsPerKm: pacePerKm)
    }

    /// フォーマット済みキロ表示（例: "1 km" or "1 mi"）
    var formattedKilometer: String {
        let km = distanceMeters / 1000
        if distanceMeters >= 950 && distanceMeters <= 1050 {
            return "\(kilometer) \(UnitFormatter.distanceUnit)"
        } else {
            return UnitFormatter.formatDistance(km)
        }
    }

    /// フォーマット済み平均心拍数
    var formattedAverageHeartRate: String? {
        guard let hr = averageHeartRate else { return nil }
        return String(format: "%.0f", hr)
    }
}
