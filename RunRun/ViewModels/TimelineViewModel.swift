import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var runs: [TimelineRun] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: Error?
    @Published private(set) var hasMore = true
    @Published private(set) var monthlyGoal: RunningGoal?

    let userId: String
    private let firestoreService = FirestoreService.shared
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20

    var dayGroups: [TimelineDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { run in
            calendar.startOfDay(for: run.date)
        }
        return grouped.map { date, runs in
            TimelineDayGroup(id: date, date: date, runs: runs.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }

    init(userId: String) {
        self.userId = userId
    }

    func onAppear() async {
        if runs.isEmpty {
            // デバッグ用遅延
            await DebugSettings.applyLoadDelay()
            await loadInitial()
        }
    }

    func refresh() async {
        lastDocument = nil
        hasMore = true
        await loadInitial()
    }

    func loadInitial() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            runs = MockDataProvider.timelineRuns
            isLoading = false
            hasMore = false
            return
        }

        // データがない場合のみローディング表示（チラつき防止）
        if runs.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            let result = try await firestoreService.getTimelineRuns(
                userId: userId,
                limit: pageSize,
                lastDocument: nil
            )
            runs = result.runs
            lastDocument = result.lastDocument
            hasMore = result.runs.count >= pageSize
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, lastDocument != nil else { return }

        isLoadingMore = true

        do {
            let result = try await firestoreService.getTimelineRuns(
                userId: userId,
                limit: pageSize,
                lastDocument: lastDocument
            )
            runs.append(contentsOf: result.runs)
            lastDocument = result.lastDocument
            hasMore = result.runs.count >= pageSize
        } catch {
            self.error = error
        }

        isLoadingMore = false
    }

    // MARK: - Monthly Goal

    func loadMonthlyGoal() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            monthlyGoal = MockDataProvider.monthlyGoal
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            monthlyGoal = try await firestoreService.getMonthlyGoal(
                userId: userId,
                year: year,
                month: month
            )
        } catch {
            print("Failed to load monthly goal: \(error)")
        }
    }

    func saveGoal(_ goal: RunningGoal) async {
        do {
            let savedGoal = try await firestoreService.setGoal(userId: userId, goal: goal)
            monthlyGoal = savedGoal
            AnalyticsService.logEvent("set_goal", parameters: [
                "type": goal.type.rawValue,
                "target_km": goal.targetDistanceKm
            ])
        } catch {
            print("Failed to save goal: \(error)")
        }
    }

    func deleteGoal() async {
        guard let goalId = monthlyGoal?.id else { return }
        do {
            try await firestoreService.deleteGoal(userId: userId, goalId: goalId)
            monthlyGoal = nil
            AnalyticsService.logEvent("delete_goal", parameters: [
                "type": "monthly"
            ])
        } catch {
            print("Failed to delete goal: \(error)")
        }
    }
}
