import Combine
import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

enum AppTab: Int {
    case home = 0
    case record = 1
    case leaderboard = 2
    case friends = 3
    case settings = 4
}

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var fcmToken: String?
    @Published var isAuthorized = false
    @Published var pendingTab: AppTab?

    private let firestoreService = FirestoreService.shared

    private override init() {
        super.init()
    }

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// デリゲートの設定のみ（許可リクエストなし）
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    /// 許可をリクエストしてリモート通知に登録
    func requestAndRegister() async {
        let granted = await requestAuthorization()
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func updateFCMToken(userId: String) async {
        guard let token = fcmToken else { return }

        do {
            try await firestoreService.updateFCMToken(userId: userId, token: token)
        } catch {
            print("Failed to update FCM token: \(error)")
        }
    }

    func removeFCMToken(userId: String) async {
        do {
            try await firestoreService.removeFCMToken(userId: userId)
        } catch {
            print("Failed to remove FCM token: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request", "friend_accepted":
                // フレンドタブに遷移
                await MainActor.run {
                    self.pendingTab = .friends
                }
            default:
                break
            }
        }
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = token
            print("FCM token: \(token)")
        }
    }
}
