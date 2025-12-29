import SwiftUI

struct ContentView: View {
    var body: some View {
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
    }
}

#Preview {
    ContentView()
}
