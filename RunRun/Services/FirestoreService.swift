import Foundation
import FirebaseFirestore
import FirebaseAuth

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private lazy var db: Firestore = Firestore.firestore()

    private init() {}

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private var runsCollection: CollectionReference {
        db.collection("runs")
    }

    // MARK: - User Profile

    /// 新規ユーザーのプロファイルを作成（初回サインイン時のみ使用）
    func createNewUserProfile(userId: String, displayName: String, email: String?) async throws {
        let data: [String: Any] = [
            "displayName": displayName,
            "email": email as Any,
            "iconName": "figure.run",
            "createdAt": Date()
        ]
        try await usersCollection.document(userId).setData(data)
    }

    /// プロファイルが存在しない場合のみ作成（ContentView等から使用）
    func createUserProfileIfNeeded(userId: String, displayName: String, email: String?) async throws {
        let docRef = usersCollection.document(userId)
        let snapshot = try await docRef.getDocument()

        if !snapshot.exists {
            let data: [String: Any] = [
                "displayName": displayName,
                "email": email as Any,
                "iconName": "figure.run",
                "createdAt": Date()
            ]
            try await docRef.setData(data)
        }
    }

    func getUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await usersCollection.document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }

        var avatarURL: URL?
        if let urlString = data["avatarURL"] as? String {
            avatarURL = URL(string: urlString)
        }

        return UserProfile(
            id: snapshot.documentID,
            displayName: data["displayName"] as? String ?? "Runner",
            email: data["email"] as? String,
            iconName: data["iconName"] as? String ?? "figure.run",
            avatarURL: avatarURL,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func updateProfile(userId: String, displayName: String, iconName: String, avatarURL: URL?) async throws {
        var updateData: [String: Any] = [
            "displayName": displayName,
            "iconName": iconName
        ]
        if let avatarURL = avatarURL {
            updateData["avatarURL"] = avatarURL.absoluteString
        }
        try await usersCollection.document(userId).updateData(updateData)
    }

    func clearAvatarURL(userId: String) async throws {
        try await usersCollection.document(userId).updateData([
            "avatarURL": FieldValue.delete()
        ])
    }

    func updateDisplayName(userId: String, displayName: String) async throws {
        try await usersCollection.document(userId).updateData([
            "displayName": displayName
        ])
    }

    // MARK: - Run Records

    @discardableResult
    func syncRunRecords(
        userId: String,
        records: [RunningRecord],
        onProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> Int {
        guard !records.isEmpty else { return 0 }

        for (index, record) in records.enumerated() {
            var data: [String: Any] = [
                "userId": userId,
                "date": record.date,
                "distanceKm": record.distanceInKilometers,
                "durationSeconds": record.durationInSeconds,
                "paceSecondsPerKm": record.averagePacePerKilometer ?? 0,
                "syncedAt": Date()
            ]

            // 詳細データ（nilでなければ保存）
            if let hr = record.averageHeartRate { data["averageHeartRate"] = hr }
            if let hr = record.maxHeartRate { data["maxHeartRate"] = hr }
            if let hr = record.minHeartRate { data["minHeartRate"] = hr }
            if let cal = record.caloriesBurned { data["caloriesBurned"] = cal }
            if let cad = record.cadence { data["cadence"] = cad }
            if let stride = record.strideLength { data["strideLength"] = stride }
            if let steps = record.stepCount { data["stepCount"] = steps }

            _ = try await runsCollection.addDocument(data: data)
            onProgress?(index + 1, records.count)
        }

        return records.count
    }

    func getUserRuns(userId: String) async throws -> [(date: Date, distanceKm: Double, durationSeconds: TimeInterval, caloriesBurned: Double?)] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> (Date, Double, TimeInterval, Double?)? in
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double,
                  let duration = data["durationSeconds"] as? TimeInterval else {
                return nil
            }
            let calories = data["caloriesBurned"] as? Double
            return (timestamp.dateValue(), distance, duration, calories)
        }
    }

    func getAllUserRunRecords(userId: String) async throws -> [RunningRecord] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
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

    private func getExistingSyncedDates(userId: String) async throws -> [Date] {
        let runs = try await getUserRuns(userId: userId)
        return runs.map { $0.date }
    }

    func getNewRecordsToSync(userId: String, records: [RunningRecord]) async throws -> [RunningRecord] {
        let existingDates = try await getExistingSyncedDates(userId: userId)
        return records.filter { record in
            !existingDates.contains { Calendar.current.isDate($0, inSameDayAs: record.date) }
        }
    }

    // MARK: - Leaderboard

    func getLeaderboard(limit: Int = 20) async throws -> [UserProfile] {
        let snapshot = try await usersCollection
            .order(by: "totalDistanceKm", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> UserProfile? in
            let data = doc.data()
            var avatarURL: URL?
            if let urlString = data["avatarURL"] as? String {
                avatarURL = URL(string: urlString)
            }
            return UserProfile(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "Runner",
                email: data["email"] as? String,
                iconName: data["iconName"] as? String ?? "figure.run",
                avatarURL: avatarURL,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                totalDistanceKm: data["totalDistanceKm"] as? Double ?? 0,
                totalRuns: data["totalRuns"] as? Int ?? 0
            )
        }
    }

    func getMonthlyLeaderboard(year: Int, month: Int, limit: Int = 20) async throws -> [UserProfile] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }

        // 該当月のラン記録を全て取得
        let snapshot = try await runsCollection
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThan: startOfNextMonth)
            .getDocuments()

        // ユーザーごとに集計
        var userStats: [String: (distance: Double, runs: Int)] = [:]
        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let distance = data["distanceKm"] as? Double else { continue }

            let current = userStats[userId] ?? (0, 0)
            userStats[userId] = (current.distance + distance, current.runs + 1)
        }

        // ユーザープロフィールを取得して結合
        var profiles: [UserProfile] = []
        for (userId, stats) in userStats {
            if let profile = try? await getUserProfile(userId: userId) {
                var monthlyProfile = profile
                monthlyProfile.totalDistanceKm = stats.distance
                monthlyProfile.totalRuns = stats.runs
                profiles.append(monthlyProfile)
            }
        }

        // 距離でソート
        return profiles.sorted { $0.totalDistanceKm > $1.totalDistanceKm }.prefix(limit).map { $0 }
    }

    // MARK: - Friend Requests

    private var friendRequestsCollection: CollectionReference {
        db.collection("friendRequests")
    }

    func sendFriendRequest(fromUserId: String, fromDisplayName: String, toUserId: String) async throws {
        // すでにフレンドならリクエスト不要
        if try await isFriend(currentUserId: fromUserId, otherUserId: toUserId) {
            return
        }

        // 相手から自分へのpendingリクエストがあるかチェック
        let reverseRequest = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: toUserId)
            .whereField("toUserId", isEqualTo: fromUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        if let reverseDoc = reverseRequest.documents.first {
            // 相手からのリクエストがある場合、自動的にフレンドになる
            try await acceptFriendRequest(
                requestId: reverseDoc.documentID,
                currentUserId: fromUserId,
                friendUserId: toUserId
            )
            return
        }

        // 既存リクエストを検索（同方向: from → to）
        let existing = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .limit(to: 1)
            .getDocuments()

        if let existingDoc = existing.documents.first {
            // 同方向の既存リクエストがある場合
            let data = existingDoc.data()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)

            if createdAt > twentyFourHoursAgo {
                // 24時間以内なら何もしない
                return
            }

            // 24時間経過していれば再申請（時間とステータスを更新）
            try await friendRequestsCollection.document(existingDoc.documentID).updateData([
                "createdAt": Date(),
                "status": "pending"
            ])
            return
        }

        // 逆方向のリクエストを検索（to → from、rejected含む）
        let reverseExisting = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: toUserId)
            .whereField("toUserId", isEqualTo: fromUserId)
            .limit(to: 1)
            .getDocuments()

        if let reverseDoc = reverseExisting.documents.first {
            // 逆方向の既存リクエストがある場合（rejectedなど）
            let data = reverseDoc.data()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)

            if createdAt > twentyFourHoursAgo {
                // 24時間以内なら何もしない
                return
            }

            // 24時間経過していれば、from/toを入れ替えて再利用
            try await friendRequestsCollection.document(reverseDoc.documentID).updateData([
                "fromUserId": fromUserId,
                "fromDisplayName": fromDisplayName,
                "toUserId": toUserId,
                "createdAt": Date(),
                "status": "pending"
            ])
            return
        }

        // 新規作成
        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "fromDisplayName": fromDisplayName,
            "toUserId": toUserId,
            "createdAt": Date(),
            "status": "pending"
        ]
        _ = try await friendRequestsCollection.addDocument(data: data)
    }

    func canSendFriendRequest(fromUserId: String, toUserId: String) async throws -> Bool {
        let existing = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        if let existingDoc = existing.documents.first {
            let data = existingDoc.data()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
            return createdAt <= twentyFourHoursAgo
        }

        return true
    }

    func getLastFriendRequestDate(fromUserId: String, toUserId: String) async throws -> Date? {
        let snapshot = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let timestamp = doc.data()["createdAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    func getFriendRequests(userId: String) async throws -> [FriendRequest] {
        let snapshot = try await friendRequestsCollection
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> FriendRequest? in
            let data = doc.data()
            guard let fromUserId = data["fromUserId"] as? String,
                  let fromDisplayName = data["fromDisplayName"] as? String,
                  let toUserId = data["toUserId"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                  let statusString = data["status"] as? String,
                  let status = FriendRequest.FriendRequestStatus(rawValue: statusString) else {
                return nil
            }
            return FriendRequest(
                id: doc.documentID,
                fromUserId: fromUserId,
                fromDisplayName: fromDisplayName,
                toUserId: toUserId,
                createdAt: createdAt,
                status: status
            )
        }
    }

    func acceptFriendRequest(requestId: String, currentUserId: String, friendUserId: String) async throws {
        // リクエストのステータスを更新
        try await friendRequestsCollection.document(requestId).updateData([
            "status": "accepted"
        ])

        // 双方向でフレンドを追加
        let now = Date()
        try await usersCollection.document(currentUserId).collection("friends").document(friendUserId).setData([
            "addedAt": now
        ])
        try await usersCollection.document(friendUserId).collection("friends").document(currentUserId).setData([
            "addedAt": now
        ])
    }

    func rejectFriendRequest(requestId: String) async throws {
        try await friendRequestsCollection.document(requestId).updateData([
            "status": "rejected"
        ])
    }

    // MARK: - Friends

    func getFriends(userId: String) async throws -> [String] {
        let snapshot = try await usersCollection.document(userId).collection("friends").getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    func getFriendProfiles(userId: String) async throws -> [UserProfile] {
        let friendIds = try await getFriends(userId: userId)
        var profiles: [UserProfile] = []
        for friendId in friendIds {
            if let profile = try await getUserProfile(userId: friendId) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    func removeFriend(currentUserId: String, friendUserId: String) async throws {
        try await usersCollection.document(currentUserId).collection("friends").document(friendUserId).delete()
        try await usersCollection.document(friendUserId).collection("friends").document(currentUserId).delete()
    }

    func isFriend(currentUserId: String, otherUserId: String) async throws -> Bool {
        let doc = try await usersCollection.document(currentUserId).collection("friends").document(otherUserId).getDocument()
        return doc.exists
    }

    func getNewFriendsCount(userId: String, since date: Date) async throws -> Int {
        let snapshot = try await usersCollection
            .document(userId)
            .collection("friends")
            .whereField("addedAt", isGreaterThan: date)
            .getDocuments()
        return snapshot.documents.count
    }

    // MARK: - User Search

    func searchUsers(query: String, excludeUserId: String) async throws -> [UserProfile] {
        guard !query.isEmpty else { return [] }

        let snapshot = try await usersCollection
            .order(by: "displayName")
            .start(at: [query])
            .end(at: [query + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> UserProfile? in
            guard doc.documentID != excludeUserId else { return nil }
            let data = doc.data()
            var avatarURL: URL?
            if let urlString = data["avatarURL"] as? String {
                avatarURL = URL(string: urlString)
            }
            return UserProfile(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "Runner",
                email: data["email"] as? String,
                iconName: data["iconName"] as? String ?? "figure.run",
                avatarURL: avatarURL,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                totalDistanceKm: data["totalDistanceKm"] as? Double ?? 0,
                totalRuns: data["totalRuns"] as? Int ?? 0
            )
        }
    }

    // MARK: - Friends Leaderboard

    func getFriendsMonthlyLeaderboard(userId: String, year: Int, month: Int) async throws -> [UserProfile] {
        let friendIds = try await getFriends(userId: userId)
        let allIds = friendIds + [userId]  // 自分も含める

        guard !allIds.isEmpty else { return [] }

        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }

        // 該当月のラン記録を全て取得
        let snapshot = try await runsCollection
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThan: startOfNextMonth)
            .getDocuments()

        // フレンドのみフィルタして集計
        var userStats: [String: (distance: Double, runs: Int)] = [:]
        for doc in snapshot.documents {
            let data = doc.data()
            guard let odUserId = data["userId"] as? String,
                  allIds.contains(odUserId),
                  let distance = data["distanceKm"] as? Double else { continue }

            let current = userStats[odUserId] ?? (0, 0)
            userStats[odUserId] = (current.distance + distance, current.runs + 1)
        }

        // ユーザープロフィールを取得して結合
        var profiles: [UserProfile] = []
        for (odUserId, stats) in userStats {
            if let profile = try? await getUserProfile(userId: odUserId) {
                var monthlyProfile = profile
                monthlyProfile.totalDistanceKm = stats.distance
                monthlyProfile.totalRuns = stats.runs
                profiles.append(monthlyProfile)
            }
        }

        return profiles.sorted { $0.totalDistanceKm > $1.totalDistanceKm }
    }

    // MARK: - User Runs by Month

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

    // MARK: - Adjacent Runs

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

    // MARK: - Weekly Stats

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

    // MARK: - Timeline

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

    // MARK: - Debug

    #if DEBUG
    func createDummyRun(userId: String, distanceKm: Double, date: Date) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "date": date,
            "distanceKm": distanceKm,
            "durationSeconds": distanceKm * 360,  // 6分/kmペース
            "paceSecondsPerKm": 360.0,
            "syncedAt": Date()
        ]
        _ = try await runsCollection.addDocument(data: data)
    }

    func createDummyFriendRequest(fromUserId: String, fromDisplayName: String, toUserId: String) async throws {
        // 既存のpendingリクエストを検索
        let existing = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        if let existingDoc = existing.documents.first {
            // 既存があれば時間を更新（24時間制限なし）
            try await friendRequestsCollection.document(existingDoc.documentID).updateData([
                "createdAt": Date()
            ])
        } else {
            // 新規作成
            let data: [String: Any] = [
                "fromUserId": fromUserId,
                "fromDisplayName": fromDisplayName,
                "toUserId": toUserId,
                "createdAt": Date(),
                "status": "pending"
            ]
            _ = try await friendRequestsCollection.addDocument(data: data)
        }
    }
    #endif

    // MARK: - FCM Token

    func updateFCMToken(userId: String, token: String) async throws {
        try await usersCollection.document(userId).updateData([
            "fcmToken": token
        ])
    }

    func removeFCMToken(userId: String) async throws {
        try await usersCollection.document(userId).updateData([
            "fcmToken": FieldValue.delete()
        ])
    }

    #if DEBUG
    /// ユーザーの全ランニングデータを削除（デバッグ用）
    func deleteAllUserRuns(userId: String) async throws -> Int {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()

        return snapshot.documents.count
    }
    #endif
}
