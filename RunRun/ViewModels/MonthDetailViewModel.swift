import Foundation
import Combine

@MainActor
final class MonthDetailViewModel: ObservableObject {
    @Published private(set) var records: [RunningRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    let userId: String
    let year: Int
    let month: Int

    private let firestoreService = FirestoreService()

    var title: String {
        "\(year)年\(month)月"
    }

    var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceInKilometers }
    }

    var formattedTotalDistance: String {
        String(format: "%.2f km", totalDistance)
    }

    init(userId: String, year: Int, month: Int) {
        self.userId = userId
        self.year = year
        self.month = month
    }

    func onAppear() async {
        await loadRecords()
    }

    func loadRecords() async {
        isLoading = true
        error = nil

        do {
            let runs = try await firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            records = runs.map {
                RunningRecord(date: $0.date, distanceKm: $0.distanceKm, durationSeconds: $0.durationSeconds)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
