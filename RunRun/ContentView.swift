import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService

    var body: some View {
        if authService.isAuthenticated {
            TabView {
                MonthlyRunningView()
                    .tabItem {
                        Label("記録", systemImage: "figure.run")
                    }

                SettingsView()
                    .tabItem {
                        Label("設定", systemImage: "gear")
                    }
            }
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
