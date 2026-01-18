import Foundation
import FirebaseFirestore

// MARK: - Run Records

extension FirestoreService {
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

    func getNewRecordsToSync(userId: String, records: [RunningRecord]) async throws -> [RunningRecord] {
        let existingRuns = try await getUserRuns(userId: userId)
        return records.filter { record in
            // タイムスタンプ（60秒以内）と距離（100m以内）の両方で重複チェック
            !existingRuns.contains { existing in
                abs(existing.date.timeIntervalSince(record.date)) < 60 &&
                abs(existing.distanceKm - record.distanceInKilometers) < 0.1
            }
        }
    }

    /// ドキュメントIDを含むユーザーのラン一覧を取得
    func getUserRunsWithIds(userId: String) async throws -> [(id: String, date: Date, distanceKm: Double)] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> (String, Date, Double)? in
            let data = doc.data()
            guard let timestamp = data["date"] as? Timestamp,
                  let distance = data["distanceKm"] as? Double else {
                return nil
            }
            return (doc.documentID, timestamp.dateValue(), distance)
        }
    }

    /// 指定したドキュメントIDのランを削除
    func deleteRuns(documentIds: [String]) async throws -> Int {
        guard !documentIds.isEmpty else { return 0 }

        for id in documentIds {
            try await runsCollection.document(id).delete()
        }

        return documentIds.count
    }
}
