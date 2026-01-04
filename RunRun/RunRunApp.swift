import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct RunRunApp: App {
    @StateObject private var authService: AuthenticationService

    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        _authService = StateObject(wrappedValue: AuthenticationService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
