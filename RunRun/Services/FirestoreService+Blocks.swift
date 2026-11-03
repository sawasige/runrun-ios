import Foundation
import FirebaseFirestore

// MARK: - Blocks

extension FirestoreService {
    func blocksCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("blocks")
    }

    /// ユーザーをブロックする。
    /// ブロック記録の作成に加えて、フレンド関係の解除と双方向の保留中の申請の取り下げまで行う。
    /// 以後の相手からの申請は Firestore ルール側で拒否される。
    func blockUser(currentUserId: String, blockedUserId: String) async throws {
        guard currentUserId != blockedUserId else { return }

        try await blocksCollection(userId: currentUserId).document(blockedUserId).setData([
            "createdAt": Date()
        ])
        if blockedUserIdsCache?.userId == currentUserId {
            blockedUserIdsCache?.ids.insert(blockedUserId)
        }

        try await removeFriend(currentUserId: currentUserId, friendUserId: blockedUserId)
        try await rejectPendingFriendRequests(between: currentUserId, and: blockedUserId)
    }

    /// ブロックを解除する。解除してもフレンド関係は戻らない
    func unblockUser(currentUserId: String, blockedUserId: String) async throws {
        try await blocksCollection(userId: currentUserId).document(blockedUserId).delete()
        if blockedUserIdsCache?.userId == currentUserId {
            blockedUserIdsCache?.ids.remove(blockedUserId)
        }
    }

    func isBlocked(currentUserId: String, otherUserId: String) async throws -> Bool {
        try await blockedUserIds(for: currentUserId).contains(otherUserId)
    }

    /// ブロック中のユーザー ID の集合。初回のみ Firestore から取得し、以後はメモリ上の値を返す。
    /// ランキングや検索結果の除外に使う
    func blockedUserIds(for userId: String) async throws -> Set<String> {
        if let cached = blockedUserIdsCache, cached.userId == userId {
            return cached.ids
        }
        let snapshot = try await blocksCollection(userId: userId).getDocuments()
        let ids = Set(snapshot.documents.map { $0.documentID })
        blockedUserIdsCache = (userId, ids)
        return ids
    }

    /// ブロック中のユーザーのプロフィール（ブロックした日時の新しい順）。退会済みなどで取得できないものは除く
    func getBlockedProfiles(userId: String) async throws -> [UserProfile] {
        let snapshot = try await blocksCollection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        blockedUserIdsCache = (userId, Set(snapshot.documents.map { $0.documentID }))

        var profiles: [UserProfile] = []
        for document in snapshot.documents {
            if let profile = try await getUserProfile(userId: document.documentID) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    /// サインアウト時などにキャッシュを破棄する
    func clearBlockedUserIdsCache() {
        blockedUserIdsCache = nil
    }

    /// 2 ユーザー間の保留中の申請を双方向とも取り下げる
    private func rejectPendingFriendRequests(between userId: String, and otherUserId: String) async throws {
        for (from, to) in [(userId, otherUserId), (otherUserId, userId)] {
            let snapshot = try await friendRequestsCollection
                .whereField("fromUserId", isEqualTo: from)
                .whereField("toUserId", isEqualTo: to)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            for document in snapshot.documents {
                try await document.reference.updateData(["status": "rejected"])
            }
        }
    }
}
