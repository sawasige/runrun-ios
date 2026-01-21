//
//  ScreenshotTests.swift
//  RunRunUITests
//
//  App Store用スクリーンショットを自動撮影
//

import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true  // テストが途中で止まらないようにする

        // Fastlane snapshot用の設定
        app.launchArguments = ["--screenshots"]
        // ライトモードを強制（環境変数で設定）
        app.launchEnvironment["UIUserInterfaceStyle"] = "Light"
        setupSnapshot(app)
        app.launch()
    }

    @MainActor
    func testTakeScreenshots() throws {
        // 縦向きに設定
        XCUIDevice.shared.orientation = .portrait

        // 起動待機
//        sleep(1)

        // システムダイアログを閉じる（Apple Account確認、通知パーミッションなど）
        dismissSystemDialogs()

        // 1. ホーム画面（タイムライン）
        snapshot("01_Timeline")

        // 2. 記録タブ
        let recordsTab = try XCTUnwrap(
            findTabOrSidebarItem("記録", "Records"),
            "記録タブが見つかりません"
        )
        recordsTab.tap()
        sleep(1)
        snapshot("02_Records")

        // 3. 月詳細画面（タイムラインのヘッダーから遷移）
        let homeTab = try XCTUnwrap(
            findTabOrSidebarItem("ホーム", "Home"),
            "ホームタブが見つかりません"
        )
        homeTab.tap()
//        sleep(1)

        let monthSummary = try XCTUnwrap(
            findElement(identifier: "timeline_month_summary"),
            "timeline_month_summary が見つかりません"
        )
        monthSummary.tap()
        sleep(1)
        snapshot("03_MonthDetail")

        // 4. ラン詳細画面（カレンダーの日付をタップ）
        let calendarDay = try XCTUnwrap(
            findElement(identifier: "calendar_day_10"),
            "calendar_day_10 が見つかりません"
        )
        calendarDay.tap()
        sleep(1) // 地図読み込み待機
        snapshot("04_RunDetail")

        // 5. 地図拡大画面
        let expandMapButton = try XCTUnwrap(
            findElement(identifier: "expand_map_button"),
            "expand_map_button が見つかりません"
        )
        expandMapButton.tap()
        sleep(1)
        snapshot("05_FullMap")

        // 6. ランキング
        // フルスクリーン地図を閉じる
        let closeMapButton = try XCTUnwrap(
            findElement(identifier: "close_full_screen_map"),
            "close_full_screen_map が見つかりません"
        )
        closeMapButton.tap()
//        sleep(1)

        let leaderboardTab = try XCTUnwrap(
            findTabOrSidebarItem("ランキング", "Leaderboard"),
            "ランキングタブが見つかりません"
        )
        leaderboardTab.tap()
        sleep(1)
        snapshot("06_Leaderboard")
    }

    /// タブバーまたはサイドバーから指定されたラベルを持つ要素を探す（iPad対応・多言語対応）
    private func findTabOrSidebarItem(_ labels: String..., timeout: TimeInterval = 5) -> XCUIElement? {
        for label in labels {
            // まずタブバーから探す（iPhone/iPad共通）
            let tabButton = app.tabBars.buttons[label]
            if tabButton.waitForExistence(timeout: timeout / TimeInterval(labels.count)) {
                return tabButton
            }

            // iPadのフローティングタブバーでは複数マッチする場合がある
            // firstMatchを使用して最初のマッチを取得
            let buttons = app.buttons.matching(identifier: label)
            if buttons.count > 0 {
                let firstButton = buttons.firstMatch
                if firstButton.waitForExistence(timeout: 1) {
                    return firstButton
                }
            }

            // labelでも検索
            let buttonsByLabel = app.buttons.matching(NSPredicate(format: "label == %@", label))
            if buttonsByLabel.count > 0 {
                let firstButton = buttonsByLabel.firstMatch
                if firstButton.waitForExistence(timeout: 1) {
                    return firstButton
                }
            }
        }

        return nil
    }

    /// 様々な要素タイプから指定されたidentifierを持つ要素を探す
    private func findElement(identifier: String, timeout: TimeInterval = 5) -> XCUIElement? {
        // 全ての要素タイプから探す
        let element = app.descendants(matching: .any)[identifier]
        if element.waitForExistence(timeout: timeout) {
            return element
        }

        // 見つからなければスクロールして再試行（複数回）
        // SwiftUIのListはtablesではなくcollectionViewsやscrollViewsとして認識される
        for _ in 0..<3 {
            // tablesを試す
            if app.tables.count > 0 {
                app.tables.firstMatch.swipeUp()
                sleep(1)
                if element.exists { return element }
            }

            // collectionViewsを試す（SwiftUI List）
            if app.collectionViews.count > 0 {
                app.collectionViews.firstMatch.swipeUp()
                sleep(1)
                if element.exists { return element }
            }

            // scrollViewsを試す
            if app.scrollViews.count > 0 {
                app.scrollViews.firstMatch.swipeUp()
                sleep(1)
                if element.exists { return element }
            }
        }

        return nil
    }

    /// システムダイアログを閉じる（日英対応）
    private func dismissSystemDialogs() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // Apple Account確認ダイアログ（日本語/英語）
        for label in ["今はしない", "Not Now"] {
            let notNowButton = springboard.buttons[label]
            if notNowButton.waitForExistence(timeout: 1) {
                notNowButton.tap()
                sleep(1)
                break
            }
        }

        // 通知パーミッションダイアログ（日本語/英語）
        for label in ["許可", "Allow"] {
            let allowButton = springboard.buttons[label]
            if allowButton.waitForExistence(timeout: 1) {
                allowButton.tap()
                sleep(1)
                break
            }
        }

        // 「許可しない」で閉じる場合（日本語/英語）
        for label in ["許可しない", "Don't Allow"] {
            let dontAllowButton = springboard.buttons[label]
            if dontAllowButton.waitForExistence(timeout: 1) {
                dontAllowButton.tap()
                sleep(1)
                break
            }
        }
    }
}
