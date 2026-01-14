import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        NotificationService.shared.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
}

@main
struct RunRunApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthenticationService()
    @StateObject private var notificationService = NotificationService.shared

    private func updateWidgetData(userId: String) async {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            let records = try await FirestoreService.shared.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            WidgetService.shared.updateFromRecords(records)
        } catch {
            // ウィジェット更新エラーは無視
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationService)
                .preferredColorScheme(ScreenshotMode.isEnabled ? .light : nil)
                .onChange(of: authService.user) { _, newUser in
                    Task {
                        if let userId = newUser?.uid {
                            await notificationService.updateFCMToken(userId: userId)
                            await updateWidgetData(userId: userId)
                        }
                    }
                }
                .task {
                    // アプリ起動時にウィジェットデータを更新
                    if let userId = authService.user?.uid {
                        await updateWidgetData(userId: userId)
                    }
                }
        }
    }
}
