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

    func getExistingSyncedDates(userId: String) async throws -> [Date] {
        let runs = try await getUserRuns(userId: userId)
        return runs.map { $0.date }
    }

    func getNewRecordsToSync(userId: String, records: [RunningRecord]) async throws -> [RunningRecord] {
        let existingDates = try await getExistingSyncedDates(userId: userId)
        return records.filter { record in
            // 開始時刻（秒単位）で重複チェック（同日複数ランに対応）
            !existingDates.contains { abs($0.timeIntervalSince(record.date)) < 60 }
        }
    }
}
