import Foundation
import FirebaseFirestore

// MARK: - User Profile

extension FirestoreService {
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
}
