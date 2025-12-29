import Foundation
import FirebaseFirestore

struct SyncedRunRecord: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let date: Date
    let distanceKm: Double
    let durationSeconds: TimeInterval
    let paceSecondsPerKm: Double?
    let syncedAt: Date

    init(userId: String, from record: RunningRecord) {
        self.userId = userId
        self.date = record.date
        self.distanceKm = record.distanceInKilometers
        self.durationSeconds = record.durationInSeconds
        self.paceSecondsPerKm = record.averagePacePerKilometer
        self.syncedAt = Date()
    }
}
