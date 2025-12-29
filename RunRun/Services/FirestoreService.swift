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
        let profile = UserProfile(displayName: displayName, email: email)
        try usersCollection.document(userId).setData(from: profile)
    }

    func getUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await usersCollection.document(userId).getDocument()
        return try snapshot.data(as: UserProfile.self)
    }

    func updateUserStats(userId: String, totalDistanceKm: Double, totalRuns: Int) async throws {
        try await usersCollection.document(userId).updateData([
            "totalDistanceKm": totalDistanceKm,
            "totalRuns": totalRuns
        ])
    }

    // MARK: - Run Records

    func syncRunRecords(userId: String, records: [RunningRecord]) async throws {
        guard !records.isEmpty else { return }

        // 既存の同期済み日付を取得して重複を除外
        let existingDates = try await getExistingSyncedDates(userId: userId)
        let newRecords = records.filter { record in
            !existingDates.contains { Calendar.current.isDate($0, inSameDayAs: record.date) }
        }

        guard !newRecords.isEmpty else { return }

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
    }

    func getUserRuns(userId: String) async throws -> [SyncedRunRecord] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: SyncedRunRecord.self) }
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

        return snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
    }
}
