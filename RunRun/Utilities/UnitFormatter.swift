import Foundation

/// 距離単位
enum DistanceUnit: String {
    case kilometers
    case miles

    static var current: DistanceUnit {
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool
            ?? defaultUseMetric
        return useMetric ? .kilometers : .miles
    }

    /// ロケールに基づくデフォルト値
    private static var defaultUseMetric: Bool {
        Locale.current.measurementSystem == .metric
    }
}

/// 単位変換とフォーマットを行うユーティリティ
struct UnitFormatter {
    static let kmToMiles = 0.621371
    static let milesToKm = 1.60934

    // MARK: - Default Value

    /// ロケールに基づくデフォルト値（@AppStorage用）
    static var defaultUseMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    // MARK: - Distance Formatting

    /// 距離をフォーマット（例: "5.23 km" or "3.25 mi"）
    static func formatDistance(_ kilometers: Double, decimals: Int = 2) -> String {
        let unit = DistanceUnit.current
        switch unit {
        case .kilometers:
            return String(format: "%.\(decimals)f km", kilometers)
        case .miles:
            let miles = kilometers * kmToMiles
            return String(format: "%.\(decimals)f mi", miles)
        }
    }

    /// 距離の数値のみをフォーマット（単位なし）
    static func formatDistanceValue(_ kilometers: Double, decimals: Int = 2) -> String {
        let unit = DistanceUnit.current
        switch unit {
        case .kilometers:
            return String(format: "%.\(decimals)f", kilometers)
        case .miles:
            let miles = kilometers * kmToMiles
            return String(format: "%.\(decimals)f", miles)
        }
    }

    // MARK: - Pace Formatting

    /// ペースをフォーマット（例: "5:30 /km" or "8:51 /mi"）
    static func formatPace(secondsPerKm: Double?) -> String {
        guard let pace = secondsPerKm, pace > 0, pace.isFinite else {
            return "--:--"
        }

        let unit = DistanceUnit.current
        let adjustedPace: Double
        let unitLabel: String

        switch unit {
        case .kilometers:
            adjustedPace = pace
            unitLabel = "/km"
        case .miles:
            adjustedPace = pace * milesToKm
            unitLabel = "/mi"
        }

        let minutes = Int(adjustedPace) / 60
        let seconds = Int(adjustedPace) % 60
        return String(format: "%d:%02d %@", minutes, seconds, unitLabel)
    }

    /// ペースをフォーマット（単位なし、例: "5:30"）
    static func formatPaceValue(secondsPerKm: Double?) -> String {
        guard let pace = secondsPerKm, pace > 0, pace.isFinite else {
            return "--:--"
        }

        let unit = DistanceUnit.current
        let adjustedPace: Double

        switch unit {
        case .kilometers:
            adjustedPace = pace
        case .miles:
            adjustedPace = pace * milesToKm
        }

        let minutes = Int(adjustedPace) / 60
        let seconds = Int(adjustedPace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Unit Labels

    /// 距離単位ラベル（"km" or "mi"）
    static var distanceUnit: String {
        switch DistanceUnit.current {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    /// ペース単位ラベル（"/km" or "/mi"）
    static var paceUnit: String {
        switch DistanceUnit.current {
        case .kilometers: return "/km"
        case .miles: return "/mi"
        }
    }
}
