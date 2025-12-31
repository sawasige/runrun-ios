import Foundation

struct FriendRequest: Identifiable {
    var id: String?
    let fromUserId: String
    let fromDisplayName: String
    let toUserId: String
    let createdAt: Date
    let status: FriendRequestStatus

    enum FriendRequestStatus: String {
        case pending
        case accepted
        case rejected
    }
}
