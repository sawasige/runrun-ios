import SwiftUI

/// NavigationPathへのappendを子Viewから実行するための環境値
struct NavigationAction {
    let append: (ScreenType) -> Void
}

private struct NavigationActionKey: EnvironmentKey {
    static let defaultValue: NavigationAction? = nil
}

extension EnvironmentValues {
    var navigationAction: NavigationAction? {
        get { self[NavigationActionKey.self] }
        set { self[NavigationActionKey.self] = newValue }
    }
}
