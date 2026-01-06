import FirebaseAnalytics

enum AnalyticsService {
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        print("[Analytics] \(name): \(parameters ?? [:])")
        #endif
        Analytics.logEvent(name, parameters: parameters)
    }

    static func setUserId(_ userId: String?) {
        #if DEBUG
        print("[Analytics] setUserId: \(userId ?? "nil")")
        #endif
        Analytics.setUserID(userId)
    }

    static func logScreenView(_ screenName: String) {
        #if DEBUG
        print("[Analytics] screen_view: \(screenName)")
        #endif
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }
}
