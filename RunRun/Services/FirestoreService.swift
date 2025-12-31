import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreService {
    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private var runsCollection: CollectionReference {
        db.collection("runs")
    }

    // MARK: - User Profile

    func createUserProfile(userId: String, displayName: String, email: String?) async throws {
        let data: [String: Any] = [
            "displayName": displayName,
            "email": email as Any,
            "createdAt": Date()
        ]
        try await usersCollection.document(userId).setData(data)
    }

    func getUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await usersCollection.document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }

        return UserProfile(
            id: snapshot.documentID,
            displayName: data["displayName"] as? String ?? "ランナー",
            email: data["email"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func updateDisplayName(userId: String, displayName: String) async throws {
        try await usersCollection.document(userId).updateData([
            "displayName": displayName
        ])
    }

    // MARK: - Run Records

    @discardableResult
    func syncRunRecords(userId: String, records: [RunningRecord]) async throws -> Int {
        guard !records.isEmpty else { return 0 }

        // 既存の同期済み日付を取得して重複を除外
        let existingDates = try await getExistingSyncedDates(userId: userId)
        let newRecords = records.filter { record in
            !existingDates.contains { Calendar.current.isDate($0, inSameDayAs: record.date) }
        }

        guard !newRecords.isEmpty else { return 0 }

        for record in newRecords {
            let data: [String: Any] = [
                "userId": userId,
                "date": record.date,
                "distanceKm": record.distanceInKilometers,
                "durationSeconds": record.durationInSeconds,
                "paceSecondsPerKm": record.averagePacePerKilometer ?? 0,
                "syncedAt": Date()
            ]
            _ = try await runsCollection.addDocument(data: data)
        }

        return newRecords.count
    }

    func getUserRuns(userId: String) async throws -> [(date: Date, distanceKm: Double, durationSeconds: TimeInterval)] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> (Date, Double, TimeInterval)? in
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double,
                  let duration = data["durationSeconds"] as? TimeInterval else {
                return nil
            }
            return (timestamp.dateValue(), distance, duration)
        }
    }

    private func getExistingSyncedDates(userId: String) async throws -> [Date] {
        let runs = try await getUserRuns(userId: userId)
        return runs.map { $0.date }
    }

    // MARK: - Leaderboard

    func getLeaderboard(limit: Int = 20) async throws -> [UserProfile] {
        let snapshot = try await usersCollection
            .order(by: "totalDistanceKm", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> UserProfile? in
            let data = doc.data()
            return UserProfile(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "ランナー",
                email: data["email"] as? String,
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
        // 既存のリクエストをチェック
        let existing = try await friendRequestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()

        guard existing.documents.isEmpty else { return }

        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "fromDisplayName": fromDisplayName,
            "toUserId": toUserId,
            "createdAt": Date(),
            "status": "pending"
        ]
        _ = try await friendRequestsCollection.addDocument(data: data)
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
            return UserProfile(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "ランナー",
                email: data["email"] as? String,
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
    #endif
}
