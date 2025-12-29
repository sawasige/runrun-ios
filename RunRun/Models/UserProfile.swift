import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    let displayName: String
    let email: String?
    let createdAt: Date
    var totalDistanceKm: Double
    var totalRuns: Int

    init(id: String? = nil, displayName: String, email: String?, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.createdAt = createdAt
        self.totalDistanceKm = 0
        self.totalRuns = 0
    }
}
