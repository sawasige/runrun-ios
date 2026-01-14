import Foundation
import WidgetKit

// MARK: - Widget Data Model (メインアプリとウィジェットで共有)

struct CumulativeDataPoint: Codable {
    let day: Int
    let distance: Double
}

struct WidgetData: Codable {
    let runDays: Set<Int>
    let totalDistance: Double
    let totalDuration: TimeInterval
    let cumulativeDistances: [CumulativeDataPoint]
    let previousMonthCumulativeDistances: [CumulativeDataPoint]
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

    /// ランニング記録からウィジェットデータを更新
    func updateFromRecords(_ records: [RunningRecord], previousMonthRecords: [RunningRecord] = []) {
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

        // 累積距離を計算
        let cumulativeDistances = buildCumulativeData(from: thisMonthRecords)
        let previousMonthCumulativeDistances = buildCumulativeData(from: previousMonthRecords)

        let data = WidgetData(
            runDays: runDays,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            cumulativeDistances: cumulativeDistances,
            previousMonthCumulativeDistances: previousMonthCumulativeDistances,
            year: currentYear,
            month: currentMonth,
            updatedAt: now
        )

        save(data)
        reloadWidgets()
    }

    private func buildCumulativeData(from records: [RunningRecord]) -> [CumulativeDataPoint] {
        let calendar = Calendar.current
        var result: [CumulativeDataPoint] = []

        // 日別に距離を合算
        var dailyDistances: [Int: Double] = [:]
        for record in records {
            let day = calendar.component(.day, from: record.date)
            dailyDistances[day, default: 0] += record.distanceInKilometers
        }

        // 日付順にソート
        let sortedDays = dailyDistances.keys.sorted()

        // 最初の記録が1日でなければ、1日の0kmから開始
        if let firstDay = sortedDays.first, firstDay > 1 {
            result.append(CumulativeDataPoint(day: 1, distance: 0))
        }

        // 累積距離を計算
        var cumulative: Double = 0
        for day in sortedDays {
            cumulative += dailyDistances[day] ?? 0
            result.append(CumulativeDataPoint(day: day, distance: cumulative))
        }

        return result
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
