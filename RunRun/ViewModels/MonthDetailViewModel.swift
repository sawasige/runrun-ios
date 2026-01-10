import Foundation
import Combine

@MainActor
final class MonthDetailViewModel: ObservableObject {
    @Published private(set) var records: [RunningRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var year: Int
    @Published private(set) var month: Int

    let userId: String

    private let firestoreService = FirestoreService.shared

    var title: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return "\(year)/\(month)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceInKilometers }
    }

    var formattedTotalDistance: String {
        String(format: "%.2f km", totalDistance)
    }

    var totalCalories: Double {
        records.compactMap { $0.caloriesBurned }.reduce(0, +)
    }

    var formattedTotalCalories: String? {
        guard totalCalories > 0 else { return nil }
        return String(format: "%.0f kcal", totalCalories)
    }

    /// ベスト日（距離）
    var bestDayByDistance: RunningRecord? {
        records.max { $0.distanceInKilometers < $1.distanceInKilometers }
    }

    /// ベスト日（ペース）- ペースは小さいほど速い
    var bestDayByPace: RunningRecord? {
        records.filter { $0.averagePacePerKilometer != nil && $0.distanceInKilometers >= 1.0 }
            .min { ($0.averagePacePerKilometer ?? .infinity) < ($1.averagePacePerKilometer ?? .infinity) }
    }

    init(userId: String, year: Int, month: Int) {
        self.userId = userId
        self.year = year
        self.month = month
    }

    func onAppear() async {
        await loadRecords()
    }

    func updateMonth(year: Int, month: Int) async {
        self.year = year
        self.month = month
        await loadRecords()
    }

    func loadRecords() async {
        // スクリーンショットモードならモックデータを使用
        if ScreenshotMode.isEnabled {
            records = MockDataProvider.monthDetailRecords
            isLoading = false
            return
        }

        // データがない場合のみローディング表示（チラつき防止）
        if records.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            records = try await firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
