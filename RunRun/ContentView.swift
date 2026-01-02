import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var syncService = SyncService()
    @State private var hasCompletedInitialSync = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if !hasCompletedInitialSync {
                    SyncProgressView(syncService: syncService)
                        .task {
                            await performInitialSync()
                        }
                } else if let userId = authService.user?.uid {
                    TabView {
                        TimelineView(userId: userId)
                            .tabItem {
                                Label("タイムライン", systemImage: "list.bullet")
                            }

                        MonthlyRunningView(userId: userId)
                            .tabItem {
                                Label("記録", systemImage: "figure.run")
                            }

                        LeaderboardView()
                            .tabItem {
                                Label("ランキング", systemImage: "trophy")
                            }

                        FriendsView()
                            .tabItem {
                                Label("フレンド", systemImage: "person.2")
                            }

                        SettingsView()
                            .tabItem {
                                Label("設定", systemImage: "gear")
                            }
                    }
                    .environmentObject(syncService)
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
