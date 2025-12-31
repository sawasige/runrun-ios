import Foundation
import Combine

enum SyncPhase {
    case idle
    case connecting
    case fetching
    case syncing(current: Int, total: Int)
    case completed(count: Int)
    case failed(Error)

    var message: String {
        switch self {
        case .idle:
            return ""
        case .connecting:
            return "HealthKitに接続中..."
        case .fetching:
            return "データを取得中..."
        case .syncing(let current, let total):
            return "同期中... \(current)/\(total)件"
        case .completed(let count):
            if count > 0 {
                return "\(count)件の新規記録を同期しました"
            }
            return "同期完了"
        case .failed:
            return "同期に失敗しました"
        }
    }

    var progress: Double {
        switch self {
        case .idle: return 0
        case .connecting: return 0.1
        case .fetching: return 0.3
        case .syncing(let current, let total):
            guard total > 0 else { return 0.5 }
            return 0.3 + (0.7 * Double(current) / Double(total))
        case .completed: return 1.0
        case .failed: return 0
        }
    }
}

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var phase: SyncPhase = .idle
    @Published private(set) var syncedCount = 0
    @Published private(set) var error: Error?

    private let healthKitService = HealthKitService()
    private let firestoreService = FirestoreService()

    func syncHealthKitData(userId: String) async {
        isSyncing = true
        error = nil
        syncedCount = 0
        phase = .connecting

        do {
            try await healthKitService.requestAuthorization()

            phase = .fetching
            let records = try await healthKitService.fetchAllRunningWorkouts()

            if records.isEmpty {
                phase = .completed(count: 0)
            } else {
                phase = .syncing(current: 0, total: records.count)
                let count = try await firestoreService.syncRunRecords(
                    userId: userId,
                    records: records
                ) { [weak self] current, total in
                    Task { @MainActor in
                        self?.phase = .syncing(current: current, total: total)
                    }
                }
                syncedCount = count
                phase = .completed(count: count)
            }
        } catch {
            self.error = error
            phase = .failed(error)
        }

        isSyncing = false
    }
}
