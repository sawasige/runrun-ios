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
            "createdAt": Date(),
            "totalDistanceKm": 0.0,
            "totalRuns": 0
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
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            totalDistanceKm: data["totalDistanceKm"] as? Double ?? 0,
            totalRuns: data["totalRuns"] as? Int ?? 0
        )
    }

    func updateUserStats(userId: String, totalDistanceKm: Double, totalRuns: Int) async throws {
        try await usersCollection.document(userId).updateData([
            "totalDistanceKm": totalDistanceKm,
            "totalRuns": totalRuns
        ])
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
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }

        // 該当月のラン記録を全て取得
        let snapshot = try await runsCollection
            .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
            .whereField("date", isLessThanOrEqualTo: endOfMonth)
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
}
