import Foundation
import FirebaseFirestore

// MARK: - Leaderboard

extension FirestoreService {
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

        // 距離でソートして上位のユーザーIDを取得
        let topUserIds = userStats
            .sorted { $0.value.distance > $1.value.distance }
            .prefix(limit)
            .map { $0.key }

        guard !topUserIds.isEmpty else { return [] }

        // 上位ユーザーのプロフィールをバッチ取得
        let profilesSnapshot = try await usersCollection
            .whereField(FieldPath.documentID(), in: topUserIds)
            .getDocuments()

        // プロフィールと統計を結合
        var profiles: [UserProfile] = []
        for doc in profilesSnapshot.documents {
            let data = doc.data()
            guard let stats = userStats[doc.documentID] else { continue }

            var avatarURL: URL?
            if let urlString = data["avatarURL"] as? String {
                avatarURL = URL(string: urlString)
            }

            let profile = UserProfile(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "Runner",
                email: data["email"] as? String,
                iconName: data["iconName"] as? String ?? "figure.run",
                avatarURL: avatarURL,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                totalDistanceKm: stats.distance,
                totalRuns: stats.runs
            )
            profiles.append(profile)
        }

        // 距離でソート（バッチ取得は順序を保証しないため）
        return profiles.sorted { $0.totalDistanceKm > $1.totalDistanceKm }
    }
}

// MARK: - Friends Leaderboard

extension FirestoreService {
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

        let userIdsWithRuns = Array(userStats.keys)
        guard !userIdsWithRuns.isEmpty else { return [] }

        // プロフィールをバッチ取得（30件ずつ分割）
        var profiles: [UserProfile] = []
        for chunk in userIdsWithRuns.chunked(into: 30) {
            let profilesSnapshot = try await usersCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for doc in profilesSnapshot.documents {
                let data = doc.data()
                guard let stats = userStats[doc.documentID] else { continue }

                var avatarURL: URL?
                if let urlString = data["avatarURL"] as? String {
                    avatarURL = URL(string: urlString)
                }

                let profile = UserProfile(
                    id: doc.documentID,
                    displayName: data["displayName"] as? String ?? "Runner",
                    email: data["email"] as? String,
                    iconName: data["iconName"] as? String ?? "figure.run",
                    avatarURL: avatarURL,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    totalDistanceKm: stats.distance,
                    totalRuns: stats.runs
                )
                profiles.append(profile)
            }
        }

        return profiles.sorted { $0.totalDistanceKm > $1.totalDistanceKm }
    }
}
