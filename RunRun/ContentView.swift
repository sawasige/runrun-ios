import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var syncService = SyncService()
    @ObservedObject private var badgeService = BadgeService.shared
    @State private var hasCompletedInitialSync = false
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            // スクリーンショットモードでは認証をスキップ
            if ScreenshotMode.isEnabled {
                screenshotTabView
            } else if authService.isAuthenticated {
                if !hasCompletedInitialSync {
                    SyncProgressView(syncService: syncService)
                        .transition(.opacity)
                        .task {
                            await performInitialSync()
                        }
                } else if let userId = authService.user?.uid {
                    mainTabView(userId: userId)
                }
            } else {
                LoginView()
            }
        }
    }

    /// スクリーンショット用のタブビュー（認証不要）
    private var screenshotTabView: some View {
        TabView(selection: $selectedTab) {
            TimelineView(userId: MockDataProvider.currentUserId)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            YearDetailView(userId: MockDataProvider.currentUserId)
                .tabItem {
                    Label("Records", systemImage: "figure.run")
                }
                .tag(AppTab.record)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tag(AppTab.leaderboard)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(AppTab.friends)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .environmentObject(syncService)
        .environmentObject(badgeService)
    }

    /// 通常のタブビュー
    private func mainTabView(userId: String) -> some View {
        TabView(selection: $selectedTab) {
            TimelineView(userId: userId)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            YearDetailView(userId: userId)
                .tabItem {
                    Label("Records", systemImage: "figure.run")
                }
                .tag(AppTab.record)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tag(AppTab.leaderboard)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .badge(badgeService.totalBadgeCount)
                .tag(AppTab.friends)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .environmentObject(syncService)
        .environmentObject(badgeService)
        .task {
            await badgeService.updateBadgeCounts(userId: userId)
        }
        .onAppear {
            // アプリ起動時に保留中のタブ遷移があれば処理
            if let tab = notificationService.pendingTab {
                selectedTab = tab
                notificationService.pendingTab = nil
            }
        }
        .onChange(of: notificationService.pendingTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                notificationService.pendingTab = nil
            }
        }
        .transition(.opacity)
    }

    private func performInitialSync() async {
        guard let userId = authService.user?.uid else { return }
        await syncService.syncHealthKitData(userId: userId)
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedInitialSync = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
