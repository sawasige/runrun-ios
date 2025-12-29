import Foundation
import Combine

@MainActor
final class MonthDetailViewModel: ObservableObject {
    @Published private(set) var records: [RunningRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    let year: Int
    let month: Int

    private let healthKitService = HealthKitService()

    var title: String {
        "\(year)年\(month)月"
    }

    var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceInKilometers }
    }

    var formattedTotalDistance: String {
        String(format: "%.2f km", totalDistance)
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    func onAppear() async {
        await loadRecords()
    }

    func loadRecords() async {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return
        }

        isLoading = true
        error = nil

        do {
            records = try await healthKitService.fetchRunningWorkouts(from: startDate, to: endDate)
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
