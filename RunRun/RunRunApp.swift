import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    static let widgetRefreshTaskIdentifier = "com.himatsubu.RunRun.widget-refresh"

    /// HealthKit監視用（解放されないように保持）
    private var healthKitService: HealthKitService?

    /// 最後に同期した時刻（スロットリング用）
    private var lastSyncTime: Date?
    /// スロットリング間隔（秒）
    private let syncThrottleInterval: TimeInterval = 10

    /// 起動時にバックグラウンドだったかどうか
    private var launchedInBackground = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // launchOptionsが空でなければバックグラウンド起動
        launchedInBackground = launchOptions != nil && !launchOptions!.isEmpty

        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        NotificationService.shared.setup()

        // バックグラウンドタスクを登録
        registerBackgroundTasks()

        // HealthKit監視を開始
        Task {
            await setupHealthKitObserver()
        }

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
        // バックグラウンドタスクを開始（サスペンドを遅延させる）
        var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "HealthKitSync") {
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                backgroundTaskId = .invalid
            }
        }

        defer {
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
            }
        }

        // スロットリング: 直近N秒以内に同期した場合はスキップ
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < syncThrottleInterval {
            return
        }

        // Firebase Auth のセッション復元を待つ（最大3秒）
        var userId = Auth.auth().currentUser?.uid
        if userId == nil {
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                userId = Auth.auth().currentUser?.uid
                if userId != nil { break }
            }
        }

        guard let userId = userId else { return }

        lastSyncTime = Date()
        // HealthKitと同期（SyncServiceが同期後にウィジェットも更新する）
        await SyncService.shared.syncHealthKitData(userId: userId, isBackgroundSync: launchedInBackground)
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

    // MARK: - HealthKit Observer

    private func setupHealthKitObserver() async {
        let service = HealthKitService()
        self.healthKitService = service  // インスタンスを保持

        do {
            try await service.enableBackgroundDelivery()
            service.startObservingWorkouts {
                // ワークアウト変更を検知したら即座に同期してウィジェットを更新
                await self.refreshWidgetData()
            }
        } catch {
            print("Failed to setup HealthKit observer: \(error)")
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

        // 前月の年月を計算
        let (prevYear, prevMonth): (Int, Int)
        if month == 1 {
            prevYear = year - 1
            prevMonth = 12
        } else {
            prevYear = year
            prevMonth = month - 1
        }

        do {
            async let currentRecords = FirestoreService.shared.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            async let prevRecords = FirestoreService.shared.getUserMonthlyRuns(
                userId: userId,
                year: prevYear,
                month: prevMonth
            )

            let records = try await currentRecords
            let previousMonthRecords = try await prevRecords
            WidgetService.shared.updateFromRecords(records, previousMonthRecords: previousMonthRecords)
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
                            // ログイン後にプッシュ通知の許可をリクエスト
                            await notificationService.requestAndRegister()
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
