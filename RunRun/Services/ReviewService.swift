import Foundation
import StoreKit
import UIKit

/// App Storeレビューリクエストを管理
final class ReviewService {
    static let shared = ReviewService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let syncCount = "review.syncCount"
        static let lastRequestedVersion = "review.lastRequestedVersion"
    }

    /// レビューをリクエストする条件
    /// - 5回以上の同期が完了している
    /// - このバージョンでまだリクエストしていない
    private let requiredSyncCount = 5

    private init() {}

    /// 同期完了時に呼び出す
    func recordSync() {
        let count = defaults.integer(forKey: Keys.syncCount) + 1
        defaults.set(count, forKey: Keys.syncCount)
    }

    /// 条件を満たしていればレビューをリクエスト
    func requestReviewIfAppropriate() {
        let syncCount = defaults.integer(forKey: Keys.syncCount)
        let lastRequestedVersion = defaults.string(forKey: Keys.lastRequestedVersion)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        // 条件チェック
        guard syncCount >= requiredSyncCount else { return }
        guard lastRequestedVersion != currentVersion else { return }

        // リクエスト
        Task { @MainActor in
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
                defaults.set(currentVersion, forKey: Keys.lastRequestedVersion)
                AnalyticsService.logEvent("review_requested", parameters: [
                    "sync_count": syncCount
                ])
            }
        }
    }
}
