import Foundation

/// デバッグ用設定
/// 開発時のみ使用。リリースビルドでは無効化される。
enum DebugSettings {
    #if DEBUG
    /// ロード遅延を有効にするかどうか
    @UserDefaultsBacked(key: "debug.loadDelayEnabled", defaultValue: false)
    static var loadDelayEnabled: Bool

    /// ロード遅延時間（秒）
    @UserDefaultsBacked(key: "debug.loadDelaySeconds", defaultValue: 2.0)
    static var loadDelaySeconds: Double

    /// 過去の目標も編集可能にする
    @UserDefaultsBacked(key: "debug.allowPastGoalEdit", defaultValue: false)
    static var allowPastGoalEdit: Bool

    /// デバッグ用の遅延を適用
    static func applyLoadDelay() async {
        guard loadDelayEnabled else { return }
        try? await Task.sleep(for: .seconds(loadDelaySeconds))
    }
    #else
    static var loadDelayEnabled: Bool { false }
    static var loadDelaySeconds: Double { 0 }
    static var allowPastGoalEdit: Bool { false }
    static func applyLoadDelay() async {}
    #endif
}

#if DEBUG
/// UserDefaultsをバックエンドとするプロパティラッパー
@propertyWrapper
struct UserDefaultsBacked<T> {
    let key: String
    let defaultValue: T
    let defaults: UserDefaults

    init(key: String, defaultValue: T, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
    }

    var wrappedValue: T {
        get {
            defaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            defaults.set(newValue, forKey: key)
        }
    }
}
#endif
