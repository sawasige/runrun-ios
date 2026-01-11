import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var syncService = SyncService()
    @ObservedObject private var badgeService = BadgeService.shared
    @State private var selectedTab: AppTab = .home
    @State private var userProfile: UserProfile?

    private let firestoreService = FirestoreService.shared

    var body: some View {
        Group {
            // スクリーンショットモードでは認証をスキップ
            if ScreenshotMode.isEnabled {
                screenshotTabView
            } else if authService.isAuthenticated {
                if let userId = authService.user?.uid {
                    Group {
                        if let profile = userProfile {
                            mainTabView(userId: userId, userProfile: profile)
                                .task {
                                    await syncService.syncHealthKitData(userId: userId)
                                }
                        } else {
                            loadingView
                                .task {
                                    let profile = try? await firestoreService.getUserProfile(userId: userId)
                                    withAnimation(.easeIn(duration: 0.3)) {
                                        userProfile = profile
                                    }
                                }
                        }
                    }
                }
            } else {
                LoginView()
            }
        }
    }

    /// スクリーンショット用のタブビュー（認証不要）
    private var screenshotTabView: some View {
        TabView(selection: $selectedTab) {
            TimelineView(userId: MockDataProvider.currentUserId, userProfile: MockDataProvider.currentUser)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            YearDetailView(user: MockDataProvider.currentUser)
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

    /// ローディングビュー
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 通常のタブビュー
    private func mainTabView(userId: String, userProfile: UserProfile) -> some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                TimelineView(userId: userId, userProfile: userProfile)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(AppTab.home)

                YearDetailView(user: userProfile)
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

            // 同期バナー
            SyncBannerView(syncService: syncService, userId: userId)
                .padding(.top, 8)
        }
        .transition(.opacity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
