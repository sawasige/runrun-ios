import SwiftUI
import FirebaseCore

@main
struct RunRunApp: App {
    @StateObject private var authService = AuthenticationService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
