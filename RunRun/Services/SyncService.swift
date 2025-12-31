import Foundation
import Combine

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var syncedCount = 0
    @Published private(set) var error: Error?

    private let healthKitService = HealthKitService()
    private let firestoreService = FirestoreService()

    func syncHealthKitData(userId: String) async {
        isSyncing = true
        error = nil
        syncedCount = 0

        do {
            try await healthKitService.requestAuthorization()

            let records = try await healthKitService.fetchAllRunningWorkouts()

            let count = try await firestoreService.syncRunRecords(userId: userId, records: records)
            syncedCount = count
        } catch {
            self.error = error
        }

        isSyncing = false
    }
}
