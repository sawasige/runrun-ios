import Foundation
import FirebaseFirestore

// MARK: - FCM Token

extension FirestoreService {
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
}

// MARK: - Debug

#if DEBUG
extension FirestoreService {
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
}
#endif
