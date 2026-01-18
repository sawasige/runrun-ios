import Foundation
import Combine
import HealthKit
import UIKit
import FirebaseCrashlytics

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
    static let shared = SyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var phase: SyncPhase = .idle
    @Published private(set) var syncedCount = 0
    @Published private(set) var error: Error?
    /// 同期完了時に更新される（新規レコードがある場合のみ）
    @Published private(set) var lastSyncedAt: Date?

    private let healthKitService = HealthKitService()
    private let firestoreService = FirestoreService.shared

    /// プレビュー用。本番では`SyncService.shared`を使用
    init() {}

    func syncHealthKitData(userId: String) async {
        // 同時実行を防止
        guard !isSyncing else { return }

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
                    let workoutDistance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    return newBasicRecords.contains { record in
                        abs(record.date.timeIntervalSince(workout.startDate)) < 60 &&
                        abs(record.distanceInMeters - workoutDistance) < 100
                    }
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

                // 同期回数を記録（レビューリクエスト用）
                ReviewService.shared.recordSync()
            }
        } catch {
            self.error = error
            phase = .failed

            // 詳細なエラーログ
            let isBackground = UIApplication.shared.applicationState != .active
            AnalyticsService.logEvent("sync_error", parameters: [
                "error": error.localizedDescription,
                "error_type": String(describing: type(of: error)),
                "is_background": isBackground
            ])

            // Crashlyticsにnon-fatalエラーとして記録
            let nsError = error as NSError
            Crashlytics.crashlytics().record(error: nsError, userInfo: [
                "is_background": isBackground,
                "phase": String(describing: phase)
            ])
        }

        isSyncing = false
    }

    /// HealthKitと完全同期（削除も含む）
    func forceSyncHealthKitData(userId: String) async -> (added: Int, deleted: Int) {
        guard !isSyncing else { return (0, 0) }

        isSyncing = true
        error = nil
        syncedCount = 0
        phase = .connecting

        var addedCount = 0
        var deletedCount = 0

        do {
            try await healthKitService.requestAuthorization()

            phase = .fetching

            // HealthKitとFirestoreのデータを並行取得
            async let healthKitWorkoutsTask = Task.detached(priority: .userInitiated) {
                try await self.healthKitService.fetchAllRawRunningWorkouts()
            }.value
            async let firestoreRunsTask = firestoreService.getUserRunsWithIds(userId: userId)

            let workouts = try await healthKitWorkoutsTask
            let firestoreRuns = try await firestoreRunsTask

            // HealthKitのワークアウトを基本情報に変換
            let healthKitRecords = workouts.map { workout in
                (date: workout.startDate, distanceKm: (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000)
            }

            // 削除対象: Firestoreにあって、HealthKitにないもの
            let toDelete = firestoreRuns.filter { firestoreRun in
                !healthKitRecords.contains { healthKitRecord in
                    abs(healthKitRecord.date.timeIntervalSince(firestoreRun.date)) < 60 &&
                    abs(healthKitRecord.distanceKm - firestoreRun.distanceKm) < 0.1
                }
            }

            // 追加対象: HealthKitにあって、Firestoreにないもの
            let toAddWorkouts = workouts.filter { workout in
                let workoutDistanceKm = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
                return !firestoreRuns.contains { firestoreRun in
                    abs(workout.startDate.timeIntervalSince(firestoreRun.date)) < 60 &&
                    abs(workoutDistanceKm - firestoreRun.distanceKm) < 0.1
                }
            }

            let totalOperations = toDelete.count + toAddWorkouts.count
            var currentOperation = 0

            // 削除実行
            if !toDelete.isEmpty {
                phase = .syncing(current: currentOperation, total: totalOperations)
                deletedCount = try await firestoreService.deleteRuns(documentIds: toDelete.map { $0.id })
                currentOperation += deletedCount
            }

            // 追加実行
            if !toAddWorkouts.isEmpty {
                let healthKit = self.healthKitService
                var detailedRecords: [RunningRecord] = []
                for workout in toAddWorkouts {
                    let record = await Task.detached(priority: .userInitiated) {
                        await healthKit.createRunningRecord(from: workout, withDetails: true)
                    }.value
                    detailedRecords.append(record)
                    currentOperation += 1
                    phase = .syncing(current: currentOperation, total: totalOperations)
                }

                addedCount = try await firestoreService.syncRunRecords(userId: userId, records: detailedRecords)
            }

            syncedCount = addedCount
            phase = .completed(count: addedCount)

            // 変更があった場合はビューの更新をトリガー
            if addedCount > 0 || deletedCount > 0 {
                lastSyncedAt = Date()
            }

            // ウィジェット更新
            await updateWidget(userId: userId)

            AnalyticsService.logEvent("force_sync_completed", parameters: [
                "added_count": addedCount,
                "deleted_count": deletedCount
            ])

        } catch {
            self.error = error
            phase = .failed
            AnalyticsService.logEvent("force_sync_error", parameters: [
                "error": error.localizedDescription
            ])
        }

        isSyncing = false
        return (addedCount, deletedCount)
    }

    /// ウィジェットデータを更新
    private func updateWidget(userId: String) async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)

            // 前月の年月を計算
            let (prevYear, prevMonth): (Int, Int)
            if month == 1 {
                prevYear = year - 1
                prevMonth = 12
            } else {
                prevYear = year
                prevMonth = month - 1
            }

            async let currentRecords = firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            async let prevRecords = firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: prevYear,
                month: prevMonth
            )

            let records = try await currentRecords
            let previousMonthRecords = try await prevRecords
            WidgetService.shared.updateFromRecords(records, previousMonthRecords: previousMonthRecords)
        } catch {
            // ウィジェット更新エラーは無視（メイン機能には影響しない）
        }
    }
}
