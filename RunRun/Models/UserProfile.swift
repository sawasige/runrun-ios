import Foundation

struct UserProfile: Identifiable {
    var id: String?
    let displayName: String
    let email: String?
    let iconName: String
    let avatarURL: URL?
    let createdAt: Date
    var totalDistanceKm: Double
    var totalRuns: Int

    static let availableIcons = [
        "figure.run",
        "figure.walk",
        "figure.hiking",
        "hare.fill",
        "tortoise.fill",
        "bolt.fill",
        "flame.fill",
        "star.fill",
        "heart.fill",
        "leaf.fill",
        "mountain.2.fill",
        "sun.max.fill"
    ]

    init(
        id: String? = nil,
        displayName: String,
        email: String?,
        iconName: String = "figure.run",
        avatarURL: URL? = nil,
        createdAt: Date = Date(),
        totalDistanceKm: Double = 0,
        totalRuns: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.iconName = iconName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.totalDistanceKm = totalDistanceKm
        self.totalRuns = totalRuns
    }
}
