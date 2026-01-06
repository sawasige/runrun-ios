import Foundation
import Combine
import HealthKit

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
            return String(localized: "Connecting to HealthKit...")
        case .fetching:
            return String(localized: "Fetching data...")
        case .syncing(let current, let total):
            return String(localized: "Syncing...") + " \(current)/\(total)"
        case .completed(let count):
            if count > 0 {
                return String(format: String(localized: "%d new records synced"), count)
            }
            return String(localized: "Sync complete")
        case .failed:
            return String(localized: "Sync failed")
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
    private let firestoreService = FirestoreService.shared

    func syncHealthKitData(userId: String) async {
        isSyncing = true
        error = nil
        syncedCount = 0
        phase = .connecting

        do {
            try await healthKitService.requestAuthorization()

            phase = .fetching
            // 生のHKWorkoutを取得
            let workouts = try await healthKitService.fetchAllRawRunningWorkouts()

            // 基本情報だけでRunningRecordを作成（差分チェック用）
            let basicRecords = workouts.map { workout in
                RunningRecord(
                    id: UUID(),
                    date: workout.startDate,
                    distanceInMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                    durationInSeconds: workout.duration
                )
            }

            // 差分を計算
            let newBasicRecords = try await firestoreService.getNewRecordsToSync(
                userId: userId,
                records: basicRecords
            )

            if newBasicRecords.isEmpty {
                phase = .completed(count: 0)
            } else {
                // 新規レコードに対応するワークアウトを特定し、詳細を取得
                let newWorkouts = workouts.filter { workout in
                    newBasicRecords.contains { Calendar.current.isDate($0.date, inSameDayAs: workout.startDate) }
                }

                phase = .syncing(current: 0, total: newWorkouts.count)

                // 詳細データを取得してRunningRecordを作成
                var detailedRecords: [RunningRecord] = []
                for (index, workout) in newWorkouts.enumerated() {
                    let record = await healthKitService.createRunningRecord(from: workout, withDetails: true)
                    detailedRecords.append(record)
                    phase = .syncing(current: index + 1, total: newWorkouts.count)
                }

                // Firestoreに同期
                let count = try await firestoreService.syncRunRecords(
                    userId: userId,
                    records: detailedRecords
                )
                syncedCount = count
                phase = .completed(count: count)
                AnalyticsService.logEvent("sync_completed", parameters: [
                    "record_count": count
                ])
            }
        } catch {
            self.error = error
            phase = .failed(error)
        }

        isSyncing = false
    }
}
