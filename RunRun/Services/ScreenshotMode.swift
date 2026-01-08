import Foundation

/// スクリーンショット撮影モードの判定
enum ScreenshotMode {
    /// --screenshots 引数で起動された場合にtrue
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--screenshots")
    }
}
