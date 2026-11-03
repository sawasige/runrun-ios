import Combine
import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth

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
    @Published var pendingRunInfo: (date: Date, distanceKm: Double)?

    private let firestoreService = FirestoreService.shared

    /// Firestore に保存済みのトークン（同じ値を毎回書き込まないための記録）
    private let uploadedTokenKey = "fcm.uploadedToken"
    private let uploadedUserIdKey = "fcm.uploadedUserId"

    private override init() {
        super.init()
    }

    /// サインアウト時に状態をリセット
    func reset() {
        pendingTab = nil
        pendingRunInfo = nil
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

    /// 現在のトークンを Firestore に保存する。前回保存した値と同じならスキップ
    func updateFCMToken(userId: String) async {
        guard let token = fcmToken else { return }

        let defaults = UserDefaults.standard
        if defaults.string(forKey: uploadedTokenKey) == token,
           defaults.string(forKey: uploadedUserIdKey) == userId {
            return
        }

        do {
            try await firestoreService.updateFCMToken(userId: userId, token: token)
            defaults.set(token, forKey: uploadedTokenKey)
            defaults.set(userId, forKey: uploadedUserIdKey)
        } catch {
            print("Failed to update FCM token: \(error)")
        }
    }

    /// サインアウト前に呼び、この端末に通知が届かないようにする
    func removeFCMToken(userId: String) async {
        do {
            try await firestoreService.removeFCMToken(userId: userId)
            UserDefaults.standard.removeObject(forKey: uploadedTokenKey)
            UserDefaults.standard.removeObject(forKey: uploadedUserIdKey)
        } catch {
            print("Failed to remove FCM token: \(error)")
        }
    }

    /// 新規ラン同期の通知を送信
    func sendNewRunNotification(records: [RunningRecord]) async {
        // バックグラウンド起動時はisAuthorizedが未設定なので、直接設定を確認
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        guard let latestRecord = records.max(by: { $0.date < $1.date }) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "New Run Synced")
        let useMetric = UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
        content.body = String(localized: "\(UnitFormatter.formatDistance(latestRecord.distanceInKilometers, useMetric: useMetric)) run recorded")
        content.sound = .default
        content.userInfo = [
            "type": "new_run",
            "runDate": latestRecord.date.timeIntervalSince1970,
            "distanceKm": latestRecord.distanceInKilometers
        ]

        // バックグラウンドからの即時配信はうまくいかないことがあるため、1秒後にトリガー
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "new_run_\(Int(latestRecord.date.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            defer { completionHandler() }

            guard let type = userInfo["type"] as? String else { return }

            switch type {
            case "new_run":
                // ラン詳細に遷移
                if let runDate = userInfo["runDate"] as? TimeInterval,
                   let distanceKm = userInfo["distanceKm"] as? Double {
                    self.pendingTab = .home
                    // タブ切り替えを待ってからpendingRunInfoを設定
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    self.pendingRunInfo = (Date(timeIntervalSince1970: runDate), distanceKm)
                }
            case "friend_request", "friend_accepted":
                // フレンドタブに遷移
                self.pendingTab = .friends
            default:
                break
            }
        }
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    /// 起動時とトークン更新時に呼ばれる。サインイン済みならその場で Firestore に保存する。
    /// サインイン直後の 1 回しか保存しないと、再インストールや更新で変わったトークンが
    /// 反映されず通知が届かなくなるため
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = token
            if let userId = Auth.auth().currentUser?.uid {
                await self.updateFCMToken(userId: userId)
            }
        }
    }
}
