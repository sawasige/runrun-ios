import Foundation
import FirebaseFirestore

// MARK: - Friend Requests

extension FirestoreService {
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
}

// MARK: - Friends

extension FirestoreService {
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
}

// MARK: - User Search

extension FirestoreService {
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
}
