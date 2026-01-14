import Foundation
import Combine
import HealthKit

enum SyncPhase: Equatable {
    case idle
    case connecting
    case fetching
    case syncing(current: Int, total: Int)
    case completed(count: Int)
    case failed

    static func == (lhs: SyncPhase, rhs: SyncPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.connecting, .connecting): return true
        case (.fetching, .fetching): return true
        case let (.syncing(lc, lt), .syncing(rc, rt)): return lc == rc && lt == rt
        case let (.completed(lc), .completed(rc)): return lc == rc
        case (.failed, .failed): return true
        default: return false
        }
    }

    var message: String {
        switch self {
        case .idle:
            return ""
        case .connecting:
            return String(localized: "Connecting to Health...")
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

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var phase: SyncPhase = .idle
    @Published private(set) var syncedCount = 0
    @Published private(set) var error: Error?
    /// 同期完了時に更新される（新規レコードがある場合のみ）
    @Published private(set) var lastSyncedAt: Date?

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

            // HealthKitのデータ取得をバックグラウンドで実行（UIブロック防止）
            let workouts = try await Task.detached(priority: .userInitiated) {
                try await self.healthKitService.fetchAllRawRunningWorkouts()
            }.value

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
                // ウィジェットを更新（新規レコードがなくても）
                await updateWidget(userId: userId)
            } else {
                // 新規レコードに対応するワークアウトを特定し、詳細を取得
                let newWorkouts = workouts.filter { workout in
                    newBasicRecords.contains { Calendar.current.isDate($0.date, inSameDayAs: workout.startDate) }
                }

                phase = .syncing(current: 0, total: newWorkouts.count)

                // 詳細データを取得してRunningRecordを作成（バックグラウンド）
                let healthKit = self.healthKitService
                var detailedRecords: [RunningRecord] = []
                for (index, workout) in newWorkouts.enumerated() {
                    let record = await Task.detached(priority: .userInitiated) {
                        await healthKit.createRunningRecord(from: workout, withDetails: true)
                    }.value
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
                if count > 0 {
                    lastSyncedAt = Date()
                }
                AnalyticsService.logEvent("sync_completed", parameters: [
                    "record_count": count
                ])

                // ウィジェットを更新
                await updateWidget(userId: userId)
            }
        } catch {
            self.error = error
            phase = .failed
            AnalyticsService.logEvent("sync_error", parameters: [
                "error": error.localizedDescription
            ])
        }

        isSyncing = false
    }

    /// ウィジェットデータを更新
    private func updateWidget(userId: String) async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)

            let records = try await firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            WidgetService.shared.updateFromRecords(records)
        } catch {
            // ウィジェット更新エラーは無視（メイン機能には影響しない）
        }
    }
}
