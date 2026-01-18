import Foundation

// MARK: - Widget Data Model

struct CumulativeDataPoint: Codable {
    let day: Int
    let distance: Double
}

struct WidgetData: Codable {
    let runDays: Set<Int>
    let runCount: Int  // 総ラン回数（同日複数回を含む）
    let totalDistance: Double
    let totalDuration: TimeInterval
    let cumulativeDistances: [CumulativeDataPoint]
    let previousMonthCumulativeDistances: [CumulativeDataPoint]
    let year: Int
    let month: Int
    let updatedAt: Date
    let useMetric: Bool  // true: km, false: miles

    // 後方互換性のためのデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runDays = try container.decode(Set<Int>.self, forKey: .runDays)
        // runCountがない場合はrunDays.countをフォールバック
        runCount = try container.decodeIfPresent(Int.self, forKey: .runCount) ?? runDays.count
        totalDistance = try container.decode(Double.self, forKey: .totalDistance)
        totalDuration = try container.decode(TimeInterval.self, forKey: .totalDuration)
        // 新しいフィールドはオプショナルとしてデコード
        cumulativeDistances = try container.decodeIfPresent([CumulativeDataPoint].self, forKey: .cumulativeDistances) ?? []
        previousMonthCumulativeDistances = try container.decodeIfPresent([CumulativeDataPoint].self, forKey: .previousMonthCumulativeDistances) ?? []
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // デフォルトはロケールに基づく
        useMetric = try container.decodeIfPresent(Bool.self, forKey: .useMetric) ?? (Locale.current.measurementSystem == .metric)
    }
}

// MARK: - Widget Data Store

final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let suiteName = "group.com.himatsubu.RunRun"
    private let key = "widgetData"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    func save(_ data: WidgetData) {
        guard let userDefaults = userDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    func load() -> WidgetData? {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }

        // 今月のデータかチェック
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if decoded.year == currentYear && decoded.month == currentMonth {
            return decoded
        }

        return nil
    }
}
