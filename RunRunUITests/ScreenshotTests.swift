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
        sleep(3)

        // システムダイアログを閉じる（Apple Account確認、通知パーミッションなど）
        dismissSystemDialogs()

        // 1. ホーム画面（タイムライン）
        snapshot("01_Timeline")

        // 2. 記録タブ
        if let recordsTab = findTabOrSidebarItem("記録") {
            recordsTab.tap()
            sleep(2)
            snapshot("02_Records")
        }

        // 3. ランキング
        if let leaderboardTab = findTabOrSidebarItem("ランキング") {
            leaderboardTab.tap()
            sleep(1)
            snapshot("03_Leaderboard")
        }

        // 4. 月詳細画面
        if let recordsTab = findTabOrSidebarItem("記録") {
            recordsTab.tap()
        }
        sleep(1)

        // NavigationLinkはListではcellsとして認識される
        if let firstMonthRow = findElement(identifier: "first_month_row") {
            firstMonthRow.tap()
            sleep(2)
            snapshot("04_MonthDetail")

            // 5. ラン詳細画面
            if let firstRunRow = findElement(identifier: "first_run_row") {
                firstRunRow.tap()
                sleep(3) // 地図読み込み待機
                snapshot("05_RunDetail")

                // 6. 地図拡大画面
                if let expandMapButton = findElement(identifier: "expand_map_button") {
                    expandMapButton.tap()
                    sleep(2)
                    snapshot("06_FullMap")
                }
            }
        }
    }

    /// タブバーまたはサイドバーから指定されたラベルを持つ要素を探す（iPad対応）
    private func findTabOrSidebarItem(_ label: String, timeout: TimeInterval = 5) -> XCUIElement? {
        // まずタブバーから探す（iPhone/iPad共通）
        let tabButton = app.tabBars.buttons[label]
        if tabButton.waitForExistence(timeout: timeout) {
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

        return nil
    }

    /// 様々な要素タイプから指定されたidentifierを持つ要素を探す
    private func findElement(identifier: String, timeout: TimeInterval = 5) -> XCUIElement? {
        // buttonsから探す
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: timeout) {
            return button
        }

        // cellsから探す（List内のNavigationLink用）
        let cell = app.cells[identifier]
        if cell.waitForExistence(timeout: 1) {
            return cell
        }

        // otherElementsから探す
        let other = app.otherElements[identifier]
        if other.waitForExistence(timeout: 1) {
            return other
        }

        // スクロールして探す
        let scrollViews = app.scrollViews
        if scrollViews.count > 0 {
            scrollViews.firstMatch.swipeUp()
            sleep(1)

            // 再度探す
            if button.exists { return button }
            if cell.exists { return cell }
            if other.exists { return other }
        }

        return nil
    }

    /// システムダイアログを閉じる
    private func dismissSystemDialogs() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // Apple Account確認ダイアログ
        let notNowButton = springboard.buttons["今はしない"]
        if notNowButton.waitForExistence(timeout: 2) {
            notNowButton.tap()
            sleep(1)
        }

        // 通知パーミッションダイアログ
        let allowButton = springboard.buttons["許可"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
            sleep(1)
        }

        // 「許可しない」で閉じる場合
        let dontAllowButton = springboard.buttons["許可しない"]
        if dontAllowButton.waitForExistence(timeout: 1) {
            dontAllowButton.tap()
            sleep(1)
        }
    }
}
