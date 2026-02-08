import Foundation
import FirebaseFirestore

// MARK: - Goals

extension FirestoreService {
    /// ユーザーの目標コレクション参照
    private func goalsCollection(userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("goals")
    }

    /// 年間目標を取得
    func getYearlyGoal(userId: String, year: Int) async throws -> RunningGoal? {
        let snapshot = try await goalsCollection(userId: userId)
            .whereField("type", isEqualTo: RunningGoal.GoalType.yearly.rawValue)
            .whereField("year", isEqualTo: year)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return goalFromDocument(doc)
    }

    /// 月間目標を取得
    func getMonthlyGoal(userId: String, year: Int, month: Int) async throws -> RunningGoal? {
        let snapshot = try await goalsCollection(userId: userId)
            .whereField("type", isEqualTo: RunningGoal.GoalType.monthly.rawValue)
            .whereField("year", isEqualTo: year)
            .whereField("month", isEqualTo: month)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return goalFromDocument(doc)
    }

    /// 目標を保存（新規作成または更新）
    /// - Returns: 保存後の目標（新規作成時はIDが設定される）
    @discardableResult
    func setGoal(userId: String, goal: RunningGoal) async throws -> RunningGoal {
        let data: [String: Any] = [
            "type": goal.type.rawValue,
            "year": goal.year,
            "month": goal.month as Any,
            "targetDistanceKm": goal.targetDistanceKm,
            "createdAt": goal.createdAt,
            "updatedAt": Date()
        ]

        if let goalId = goal.id {
            // 既存の目標を更新
            try await goalsCollection(userId: userId).document(goalId).setData(data)
            return goal
        } else {
            // 新規作成
            let docRef = try await goalsCollection(userId: userId).addDocument(data: data)
            var newGoal = goal
            newGoal.id = docRef.documentID
            return newGoal
        }
    }

    /// 目標を削除
    func deleteGoal(userId: String, goalId: String) async throws {
        try await goalsCollection(userId: userId).document(goalId).delete()
    }

    /// 直近の月間目標を取得（デフォルト値用）
    /// 年月の降順で最も新しい期間の目標を返す
    func getLatestMonthlyGoal(userId: String) async throws -> RunningGoal? {
        let snapshot = try await goalsCollection(userId: userId)
            .whereField("type", isEqualTo: RunningGoal.GoalType.monthly.rawValue)
            .order(by: "year", descending: true)
            .order(by: "month", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        let goal = goalFromDocument(doc)
        #if DEBUG
        print("[Goals] Latest monthly goal: \(goal?.year ?? 0)/\(goal?.month ?? 0) = \(goal?.targetDistanceKm ?? 0)km")
        #endif
        return goal
    }

    /// 直近の年間目標を取得（デフォルト値用）
    /// 年の降順で最も新しい年の目標を返す
    func getLatestYearlyGoal(userId: String) async throws -> RunningGoal? {
        let snapshot = try await goalsCollection(userId: userId)
            .whereField("type", isEqualTo: RunningGoal.GoalType.yearly.rawValue)
            .order(by: "year", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return goalFromDocument(doc)
    }

    /// ドキュメントからRunningGoalを生成
    private func goalFromDocument(_ doc: DocumentSnapshot) -> RunningGoal? {
        guard let data = doc.data(),
              let typeString = data["type"] as? String,
              let type = RunningGoal.GoalType(rawValue: typeString),
              let year = data["year"] as? Int,
              let targetDistanceKm = data["targetDistanceKm"] as? Double else {
            return nil
        }

        return RunningGoal(
            id: doc.documentID,
            type: type,
            year: year,
            month: data["month"] as? Int,
            targetDistanceKm: targetDistanceKm,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
