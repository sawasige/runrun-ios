import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    static let widgetRefreshTaskIdentifier = "com.himatsubu.RunRun.widget-refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        NotificationService.shared.registerForRemoteNotifications()

        // バックグラウンドタスクを登録
        registerBackgroundTasks()

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

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.widgetRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleWidgetRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleWidgetRefresh(task: BGAppRefreshTask) {
        // 次のリフレッシュをスケジュール
        scheduleWidgetRefresh()

        let refreshTask = Task {
            await refreshWidgetData()
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        Task {
            await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }

    private func refreshWidgetData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // HealthKitと同期（SyncServiceが同期後にウィジェットも更新する）
        let syncService = await SyncService()
        await syncService.syncHealthKitData(userId: userId)
    }

    func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.widgetRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分後

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule widget refresh: \(error)")
        }
    }
}

@main
struct RunRunApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthenticationService()
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        // バックグラウンドに入る時にリフレッシュをスケジュール
                        delegate.scheduleWidgetRefresh()
                    }
                }
        }
    }
}
