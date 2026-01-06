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

    func updateMonth(year: Int, month: Int) async {
        self.year = year
        self.month = month
        await loadRecords()
    }

    func loadRecords() async {
        isLoading = true
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
