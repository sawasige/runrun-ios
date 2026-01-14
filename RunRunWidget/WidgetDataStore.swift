import Foundation

// MARK: - Widget Data Model

struct WidgetData: Codable {
    let runDays: Set<Int>
    let totalDistance: Double
    let year: Int
    let month: Int
    let updatedAt: Date
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
