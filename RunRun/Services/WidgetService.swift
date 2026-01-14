import Foundation
import WidgetKit

// MARK: - Widget Data Model (メインアプリとウィジェットで共有)

struct WidgetData: Codable {
    let runDays: Set<Int>
    let totalDistance: Double
    let totalDuration: TimeInterval
    let year: Int
    let month: Int
    let updatedAt: Date
}

// MARK: - Widget Service

final class WidgetService {
    static let shared = WidgetService()

    private let suiteName = "group.com.himatsubu.RunRun"
    private let key = "widgetData"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    /// ウィジェットデータを更新
    func updateWidgetData(runDays: Set<Int>, totalDistance: Double, totalDuration: TimeInterval) {
        let calendar = Calendar.current
        let now = Date()

        let data = WidgetData(
            runDays: runDays,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            updatedAt: now
        )

        save(data)
        reloadWidgets()
    }

    /// ランニング記録からウィジェットデータを更新
    func updateFromRecords(_ records: [RunningRecord]) {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // 今月の記録のみをフィルタ
        let thisMonthRecords = records.filter { record in
            let recordYear = calendar.component(.year, from: record.date)
            let recordMonth = calendar.component(.month, from: record.date)
            return recordYear == currentYear && recordMonth == currentMonth
        }

        // ランのある日を集計
        var runDays = Set<Int>()
        var totalDistance: Double = 0
        var totalDuration: TimeInterval = 0

        for record in thisMonthRecords {
            let day = calendar.component(.day, from: record.date)
            runDays.insert(day)
            totalDistance += record.distanceInKilometers
            totalDuration += record.durationInSeconds
        }

        updateWidgetData(runDays: runDays, totalDistance: totalDistance, totalDuration: totalDuration)
    }

    private func save(_ data: WidgetData) {
        guard let userDefaults = userDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
