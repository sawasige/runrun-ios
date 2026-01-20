import Foundation

/// 距離単位
enum DistanceUnit: String {
    case kilometers
    case miles

    static func current(useMetric: Bool) -> DistanceUnit {
        useMetric ? .kilometers : .miles
    }
}

/// 単位変換とフォーマットを行うユーティリティ
struct UnitFormatter {
    static let kmToMiles = 0.621371
    static let milesToKm = 1.60934

    /// ロケールに基づくデフォルト値
    static var defaultUseMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    // MARK: - Distance Conversion

    /// キロメートルを指定単位に変換（数値のみ）
    static func convertDistance(_ kilometers: Double, useMetric: Bool) -> Double {
        if useMetric {
            return kilometers
        } else {
            return kilometers * kmToMiles
        }
    }

    // MARK: - Distance Formatting

    /// 距離をフォーマット（例: "5.23 km" or "3.25 mi"）
    static func formatDistance(_ kilometers: Double, useMetric: Bool, decimals: Int = 2) -> String {
        if useMetric {
            return String(format: "%.\(decimals)f km", kilometers)
        } else {
            let miles = kilometers * kmToMiles
            return String(format: "%.\(decimals)f mi", miles)
        }
    }

    /// 距離の数値のみをフォーマット（単位なし）
    static func formatDistanceValue(_ kilometers: Double, useMetric: Bool, decimals: Int = 2) -> String {
        if useMetric {
            return String(format: "%.\(decimals)f", kilometers)
        } else {
            let miles = kilometers * kmToMiles
            return String(format: "%.\(decimals)f", miles)
        }
    }

    // MARK: - Pace Formatting

    /// ペースをフォーマット（例: "5:30 /km" or "8:51 /mi"）
    static func formatPace(secondsPerKm: Double?, useMetric: Bool) -> String {
        guard let pace = secondsPerKm, pace > 0, pace.isFinite else {
            return "--:--"
        }

        let adjustedPace: Double
        let unitLabel: String

        if useMetric {
            adjustedPace = pace
            unitLabel = "/km"
        } else {
            adjustedPace = pace * milesToKm
            unitLabel = "/mi"
        }

        let minutes = Int(adjustedPace) / 60
        let seconds = Int(adjustedPace) % 60
        return String(format: "%d:%02d %@", minutes, seconds, unitLabel)
    }

    /// ペースをフォーマット（単位なし、例: "5:30"）
    static func formatPaceValue(secondsPerKm: Double?, useMetric: Bool) -> String {
        guard let pace = secondsPerKm, pace > 0, pace.isFinite else {
            return "--:--"
        }

        let adjustedPace: Double

        if useMetric {
            adjustedPace = pace
        } else {
            adjustedPace = pace * milesToKm
        }

        let minutes = Int(adjustedPace) / 60
        let seconds = Int(adjustedPace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Duration Formatting

    /// 時間をフォーマット（例: "1h 30m" or "45m"）
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "%dh %dm", comment: "Duration format"), hours, minutes)
        }
        return String(format: String(localized: "%dm", comment: "Minutes only"), minutes)
    }

    // MARK: - Calories Formatting

    /// カロリーをフォーマット（例: "320 kcal"）
    static func formatCalories(_ calories: Double) -> String? {
        guard calories > 0 else { return nil }
        return String(format: "%.0f kcal", calories)
    }

    // MARK: - Unit Labels

    /// 距離単位ラベル（"km" or "mi"）
    static func distanceUnit(useMetric: Bool) -> String {
        useMetric ? "km" : "mi"
    }

    /// ペース単位ラベル（"/km" or "/mi"）
    static func paceUnit(useMetric: Bool) -> String {
        useMetric ? "/km" : "/mi"
    }
}
