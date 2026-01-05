import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class BadgeService: ObservableObject {
    static let shared = BadgeService()

    @Published var unreadRequestCount: Int = 0
    @Published var newFriendCount: Int = 0

    var totalBadgeCount: Int {
        unreadRequestCount + newFriendCount
    }

    private let firestoreService = FirestoreService.shared

    private init() {}

    // MARK: - Last Seen Timestamps

    private func lastSeenRequestsKey(userId: String) -> String {
        "lastSeenRequestsDate_\(userId)"
    }

    private func lastSeenFriendsKey(userId: String) -> String {
        "lastSeenFriendsDate_\(userId)"
    }

    func getLastSeenRequestsDate(userId: String) -> Date {
        UserDefaults.standard.object(forKey: lastSeenRequestsKey(userId: userId)) as? Date ?? .distantPast
    }

    func getLastSeenFriendsDate(userId: String) -> Date {
        UserDefaults.standard.object(forKey: lastSeenFriendsKey(userId: userId)) as? Date ?? .distantPast
    }

    func markRequestsAsSeen(userId: String) {
        UserDefaults.standard.set(Date(), forKey: lastSeenRequestsKey(userId: userId))
        unreadRequestCount = 0
        updateAppIconBadge()
    }

    func markFriendsAsSeen(userId: String) {
        UserDefaults.standard.set(Date(), forKey: lastSeenFriendsKey(userId: userId))
        newFriendCount = 0
        updateAppIconBadge()
    }

    // MARK: - Badge Count

    func updateBadgeCounts(userId: String) async {
        do {
            let lastSeenRequests = getLastSeenRequestsDate(userId: userId)
            let lastSeenFriends = getLastSeenFriendsDate(userId: userId)

            // 未読フレンドリクエスト数を取得
            let requests = try await firestoreService.getFriendRequests(userId: userId)
            unreadRequestCount = requests.filter { $0.createdAt > lastSeenRequests }.count

            // 新規フレンド数を取得（自分が送ったリクエストが承認された場合）
            let newFriendsCount = try await firestoreService.getNewFriendsCount(
                userId: userId,
                since: lastSeenFriends
            )
            newFriendCount = newFriendsCount

            updateAppIconBadge()
        } catch {
            print("Failed to update badge counts: \(error)")
        }
    }

    // MARK: - App Icon Badge

    func updateAppIconBadge() {
        UNUserNotificationCenter.current().setBadgeCount(totalBadgeCount)
    }

    func clearAppIconBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
