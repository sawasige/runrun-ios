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
            if authService.isAuthenticated {
                if !hasCompletedInitialSync {
                    SyncProgressView(syncService: syncService)
                        .task {
                            await performInitialSync()
                        }
                } else if let userId = authService.user?.uid {
                    TabView(selection: $selectedTab) {
                        TimelineView(userId: userId)
                            .tabItem {
                                Label("ホーム", systemImage: "house")
                            }
                            .tag(AppTab.home)

                        MonthlyRunningView(userId: userId)
                            .tabItem {
                                Label("記録", systemImage: "figure.run")
                            }
                            .tag(AppTab.record)

                        LeaderboardView()
                            .tabItem {
                                Label("ランキング", systemImage: "trophy")
                            }
                            .tag(AppTab.leaderboard)

                        FriendsView()
                            .tabItem {
                                Label("フレンド", systemImage: "person.2")
                            }
                            .badge(badgeService.totalBadgeCount)
                            .tag(AppTab.friends)

                        SettingsView()
                            .tabItem {
                                Label("設定", systemImage: "gear")
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
                }
            } else {
                LoginView()
            }
        }
    }

    private func performInitialSync() async {
        guard let userId = authService.user?.uid else { return }
        await syncService.syncHealthKitData(userId: userId)
        hasCompletedInitialSync = true
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
