import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var notificationService: NotificationService
    @ObservedObject private var syncService = SyncService.shared
    @ObservedObject private var badgeService = BadgeService.shared
    @State private var selectedTab: AppTab = .home
    @State private var userProfile: UserProfile?
    @State private var profileLoadError: Error?
    @State private var hasProcessedInitialPendingTab = false

    // 各タブのNavigationPath
    @State private var homeNavigationPath = NavigationPath()
    @State private var recordNavigationPath = NavigationPath()
    @State private var leaderboardNavigationPath = NavigationPath()
    @State private var friendsNavigationPath = NavigationPath()
    @State private var settingsNavigationPath = NavigationPath()

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
                        } else if let error = profileLoadError {
                            profileErrorView(error: error, userId: userId)
                        } else {
                            loadingView
                                .task {
                                    await loadProfile(userId: userId)
                                }
                        }
                    }
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            // サインイン時にタブと状態をリセット
            if !oldValue && newValue {
                selectedTab = .home
                userProfile = nil
                profileLoadError = nil
                hasProcessedInitialPendingTab = false
            }
        }
    }

    /// スクリーンショット用のタブビュー（認証不要）
    private var screenshotTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeNavigationPath) {
                TimelineView(userId: MockDataProvider.currentUserId, userProfile: MockDataProvider.currentUser, navigationPath: $homeNavigationPath)
                    .navigationDestination(for: ScreenType.self) { screen in
                        destinationView(for: screen)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack(path: $recordNavigationPath) {
                YearDetailView(user: MockDataProvider.currentUser)
                    .navigationDestination(for: ScreenType.self) { screen in
                        destinationView(for: screen)
                    }
            }
            .tabItem {
                Label("Records", systemImage: "figure.run")
            }
            .tag(AppTab.record)

            NavigationStack(path: $leaderboardNavigationPath) {
                LeaderboardView()
                    .navigationDestination(for: ScreenType.self) { screen in
                        destinationView(for: screen)
                    }
            }
            .tabItem {
                Label("Leaderboard", systemImage: "trophy")
            }
            .tag(AppTab.leaderboard)

            NavigationStack(path: $friendsNavigationPath) {
                FriendsView()
                    .navigationDestination(for: ScreenType.self) { screen in
                        destinationView(for: screen)
                    }
            }
            .tabItem {
                Label("Friends", systemImage: "person.2")
            }
            .tag(AppTab.friends)

            NavigationStack(path: $settingsNavigationPath) {
                SettingsView()
                    .navigationDestination(for: ScreenType.self) { screen in
                        destinationView(for: screen)
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(AppTab.settings)
        }
        .tabViewStyle(.sidebarAdaptable)
        .environmentObject(syncService)
        .environmentObject(badgeService)
    }

    /// ローディングビュー
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// プロファイル読み込みエラービュー
    private func profileErrorView(error: Error, userId: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text("Failed to load profile")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                profileLoadError = nil
                Task {
                    await loadProfile(userId: userId)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    /// プロファイル読み込み
    private func loadProfile(userId: String) async {
        do {
            let profile = try await firestoreService.getUserProfile(userId: userId)
            if let profile = profile {
                withAnimation(.easeIn(duration: 0.3)) {
                    userProfile = profile
                }
            } else {
                // プロファイルが存在しない場合は作成を試みる
                try await firestoreService.createUserProfileIfNeeded(
                    userId: userId,
                    displayName: authService.user?.displayName ?? String(localized: "Runner"),
                    email: authService.user?.email
                )
                let newProfile = try await firestoreService.getUserProfile(userId: userId)
                withAnimation(.easeIn(duration: 0.3)) {
                    userProfile = newProfile
                }
            }
        } catch {
            profileLoadError = error
        }
    }

    /// 通常のタブビュー
    private func mainTabView(userId: String, userProfile: UserProfile) -> some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $homeNavigationPath) {
                    TimelineView(userId: userId, userProfile: userProfile, navigationPath: $homeNavigationPath)
                        .navigationDestination(for: ScreenType.self) { screen in
                            destinationView(for: screen)
                        }
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

                NavigationStack(path: $recordNavigationPath) {
                    YearDetailView(user: userProfile)
                        .navigationDestination(for: ScreenType.self) { screen in
                            destinationView(for: screen)
                        }
                }
                .tabItem {
                    Label("Records", systemImage: "figure.run")
                }
                .tag(AppTab.record)

                NavigationStack(path: $leaderboardNavigationPath) {
                    LeaderboardView()
                        .navigationDestination(for: ScreenType.self) { screen in
                            destinationView(for: screen)
                        }
                }
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tag(AppTab.leaderboard)

                NavigationStack(path: $friendsNavigationPath) {
                    FriendsView()
                        .navigationDestination(for: ScreenType.self) { screen in
                            destinationView(for: screen)
                        }
                }
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .badge(badgeService.totalBadgeCount)
                .tag(AppTab.friends)

                NavigationStack(path: $settingsNavigationPath) {
                    SettingsView()
                        .navigationDestination(for: ScreenType.self) { screen in
                            destinationView(for: screen)
                        }
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
            }
            .tabViewStyle(.sidebarAdaptable)
            .environmentObject(syncService)
            .environmentObject(badgeService)
            .task {
                await badgeService.updateBadgeCounts(userId: userId)
            }
            .onAppear {
                // アプリ起動時に保留中のタブ遷移があれば処理（初回のみ）
                if !hasProcessedInitialPendingTab, let tab = notificationService.pendingTab {
                    hasProcessedInitialPendingTab = true
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
            .onChange(of: notificationService.pendingRunInfo?.date) { _, newValue in
                if newValue != nil {
                    selectedTab = .home
                    // タブ切り替え後に少し待ってからNavigationPathをリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        homeNavigationPath = NavigationPath()
                    }
                }
            }

            // 同期バナー
            SyncBannerView(syncService: syncService, userId: userId)
                .padding(.top, 8)
        }
        .transition(.opacity)
    }

    /// ScreenTypeに応じた遷移先Viewを返す
    @ViewBuilder
    private func destinationView(for screen: ScreenType) -> some View {
        switch screen {
        case .profile(let user):
            ProfileView(user: user)
        case .yearDetail(let user, let initialYear):
            YearDetailView(user: user, initialYear: initialYear)
        case .monthDetail(let user, let year, let month):
            MonthDetailView(user: user, year: year, month: month)
        case .runDetail(let record, let user):
            RunDetailView(record: record, user: user)
        case .weeklyStats(let user):
            WeeklyStatsView(user: user)
        case .licenses:
            LicensesView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
