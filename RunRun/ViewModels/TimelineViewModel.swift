import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var runs: [TimelineRun] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: Error?
    @Published private(set) var hasMore = true

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

        isLoading = true
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
}
