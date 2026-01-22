import Foundation
import FirebaseFirestore

// MARK: - User Runs by Month

extension FirestoreService {
    func getUserMonthlyRuns(userId: String, year: Int, month: Int) async throws -> [RunningRecord] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }

        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThan: startOfNextMonth)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> RunningRecord? in
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double,
                  let duration = data["durationSeconds"] as? TimeInterval else {
                return nil
            }
            return RunningRecord(
                date: timestamp.dateValue(),
                distanceKm: distance,
                durationSeconds: duration,
                caloriesBurned: data["caloriesBurned"] as? Double,
                averageHeartRate: data["averageHeartRate"] as? Double,
                maxHeartRate: data["maxHeartRate"] as? Double,
                minHeartRate: data["minHeartRate"] as? Double,
                cadence: data["cadence"] as? Double,
                strideLength: data["strideLength"] as? Double,
                stepCount: data["stepCount"] as? Int
            )
        }
    }

    func getUserYearlyRuns(userId: String, year: Int) async throws -> [RunningRecord] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let startOfNextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }

        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: startOfYear)
            .whereField("date", isLessThan: startOfNextYear)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> RunningRecord? in
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double,
                  let duration = data["durationSeconds"] as? TimeInterval else {
                return nil
            }
            return RunningRecord(
                date: timestamp.dateValue(),
                distanceKm: distance,
                durationSeconds: duration,
                caloriesBurned: data["caloriesBurned"] as? Double,
                averageHeartRate: data["averageHeartRate"] as? Double,
                maxHeartRate: data["maxHeartRate"] as? Double,
                minHeartRate: data["minHeartRate"] as? Double,
                cadence: data["cadence"] as? Double,
                strideLength: data["strideLength"] as? Double,
                stepCount: data["stepCount"] as? Int
            )
        }
    }
}

// MARK: - Adjacent Runs

extension FirestoreService {
    enum RunDirection {
        case previous
        case next
    }

    func getAdjacentRun(userId: String, currentDate: Date, direction: RunDirection) async throws -> RunningRecord? {
        let query: Query
        // Firestoreの日付比較精度の問題を回避するため、1ミリ秒のオフセットを追加
        let epsilon: TimeInterval = 0.001

        switch direction {
        case .previous:
            let offsetDate = currentDate.addingTimeInterval(-epsilon)
            query = runsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("date", isLessThan: offsetDate)
                .order(by: "date", descending: true)
                .limit(to: 1)
        case .next:
            let offsetDate = currentDate.addingTimeInterval(epsilon)
            query = runsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("date", isGreaterThan: offsetDate)
                .order(by: "date", descending: false)
                .limit(to: 1)
        }

        let snapshot = try await query.getDocuments()
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()

        guard let timestamp = data["date"] as? Timestamp,
              let distance = data["distanceKm"] as? Double,
              let duration = data["durationSeconds"] as? TimeInterval else {
            return nil
        }

        return RunningRecord(
            date: timestamp.dateValue(),
            distanceKm: distance,
            durationSeconds: duration,
            caloriesBurned: data["caloriesBurned"] as? Double,
            averageHeartRate: data["averageHeartRate"] as? Double,
            maxHeartRate: data["maxHeartRate"] as? Double,
            minHeartRate: data["minHeartRate"] as? Double,
            cadence: data["cadence"] as? Double,
            strideLength: data["strideLength"] as? Double,
            stepCount: data["stepCount"] as? Int
        )
    }

    /// 最古のランを取得
    func getOldestRun(userId: String) async throws -> RunningRecord? {
        let query = runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: false)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()

        guard let timestamp = data["date"] as? Timestamp,
              let distance = data["distanceKm"] as? Double,
              let duration = data["durationSeconds"] as? TimeInterval else {
            return nil
        }

        return RunningRecord(
            date: timestamp.dateValue(),
            distanceKm: distance,
            durationSeconds: duration,
            caloriesBurned: data["caloriesBurned"] as? Double,
            averageHeartRate: data["averageHeartRate"] as? Double,
            maxHeartRate: data["maxHeartRate"] as? Double,
            minHeartRate: data["minHeartRate"] as? Double,
            cadence: data["cadence"] as? Double,
            strideLength: data["strideLength"] as? Double,
            stepCount: data["stepCount"] as? Int
        )
    }

    /// 最新のランを取得
    func getLatestRun(userId: String) async throws -> RunningRecord? {
        let query = runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()

        guard let timestamp = data["date"] as? Timestamp,
              let distance = data["distanceKm"] as? Double,
              let duration = data["durationSeconds"] as? TimeInterval else {
            return nil
        }

        return RunningRecord(
            date: timestamp.dateValue(),
            distanceKm: distance,
            durationSeconds: duration,
            caloriesBurned: data["caloriesBurned"] as? Double,
            averageHeartRate: data["averageHeartRate"] as? Double,
            maxHeartRate: data["maxHeartRate"] as? Double,
            minHeartRate: data["minHeartRate"] as? Double,
            cadence: data["cadence"] as? Double,
            strideLength: data["strideLength"] as? Double,
            stepCount: data["stepCount"] as? Int
        )
    }
}

// MARK: - Weekly Stats

extension FirestoreService {
    func getUserWeeklyStats(userId: String, weeks: Int = 12) async throws -> [WeeklyRunningStats] {
        let calendar = Calendar.current
        let today = Date()

        // 今週の月曜日を取得
        guard let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }

        // 指定週数前から今週までのデータを取得
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart) else {
            return []
        }

        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .getDocuments()

        // 週ごとに集計
        var weeklyData: [Date: (distance: Double, duration: TimeInterval, count: Int)] = [:]

        for doc in snapshot.documents {
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double,
                  let duration = data["durationSeconds"] as? TimeInterval else {
                continue
            }

            let runDate = timestamp.dateValue()
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: runDate)) else {
                continue
            }

            let current = weeklyData[weekStart] ?? (0, 0, 0)
            weeklyData[weekStart] = (current.distance + distance, current.duration + duration, current.count + 1)
        }

        // 全週のデータを作成（データがない週も含む）
        var stats: [WeeklyRunningStats] = []
        var currentWeek = startDate

        while currentWeek <= thisWeekStart {
            let data = weeklyData[currentWeek] ?? (0, 0, 0)
            stats.append(WeeklyRunningStats(
                weekStartDate: currentWeek,
                totalDistanceInMeters: data.distance * 1000,
                totalDurationInSeconds: data.duration,
                runCount: data.count
            ))
            currentWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
        }

        return stats
    }
}

// MARK: - Timeline

extension FirestoreService {
    func getTimelineRuns(
        userId: String,
        limit: Int,
        lastDocument: DocumentSnapshot?
    ) async throws -> (runs: [TimelineRun], lastDocument: DocumentSnapshot?) {
        // フレンドのIDを取得
        let friendIds = try await getFriends(userId: userId)
        let allUserIds = [userId] + friendIds

        // ユーザープロフィールをキャッシュ
        var profileCache: [String: UserProfile] = [:]
        for uid in allUserIds {
            if let profile = try? await getUserProfile(userId: uid) {
                profileCache[uid] = profile
            }
        }

        // Firestoreの制限: whereField in は最大30件まで
        // フレンドが30人を超える場合は分割クエリが必要
        var allRuns: [TimelineRun] = []
        var finalLastDocument: DocumentSnapshot?

        let chunks = allUserIds.chunked(into: 30)
        for chunk in chunks {
            var query = runsCollection
                .whereField("userId", in: chunk)
                .order(by: "date", descending: true)
                .limit(to: limit)

            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let timestamp = data["date"] as? Timestamp,
                      let distance = data["distanceKm"] as? Double,
                      let duration = data["durationSeconds"] as? TimeInterval,
                      let runUserId = data["userId"] as? String else {
                    continue
                }

                let profile = profileCache[runUserId]
                allRuns.append(TimelineRun(
                    id: doc.documentID,
                    date: timestamp.dateValue(),
                    distanceKm: distance,
                    durationSeconds: duration,
                    userId: runUserId,
                    displayName: profile?.displayName ?? "Runner",
                    avatarURL: profile?.avatarURL,
                    iconName: profile?.iconName ?? "figure.run",
                    caloriesBurned: data["caloriesBurned"] as? Double,
                    averageHeartRate: data["averageHeartRate"] as? Double,
                    maxHeartRate: data["maxHeartRate"] as? Double,
                    minHeartRate: data["minHeartRate"] as? Double,
                    cadence: data["cadence"] as? Double,
                    strideLength: data["strideLength"] as? Double,
                    stepCount: data["stepCount"] as? Int
                ))
            }

            if let lastDoc = snapshot.documents.last {
                finalLastDocument = lastDoc
            }
        }

        // 日付でソート
        allRuns.sort { $0.date > $1.date }

        // limit件数に制限
        let limitedRuns = Array(allRuns.prefix(limit))

        return (limitedRuns, finalLastDocument)
    }
}
