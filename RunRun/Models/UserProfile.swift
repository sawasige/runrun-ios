import Foundation

struct UserProfile: Identifiable {
    var id: String?
    let displayName: String
    let email: String?
    let createdAt: Date
    var totalDistanceKm: Double
    var totalRuns: Int

    init(
        id: String? = nil,
        displayName: String,
        email: String?,
        createdAt: Date = Date(),
        totalDistanceKm: Double = 0,
        totalRuns: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.createdAt = createdAt
        self.totalDistanceKm = totalDistanceKm
        self.totalRuns = totalRuns
    }
}
