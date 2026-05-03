# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RunRunはApple Watchのランニング記録を月別に表示し、他のユーザーとランキングで競えるiOSアプリ。

## Tech Stack

- **UI**: SwiftUI (iOS 18+)
- **Architecture**: MVVM
- **Data Source**: HealthKit (Apple Watchの運動データ)
- **Backend**: Firebase (Authentication, Firestore)
- **認証**: Sign in with Apple
- **Widget**: WidgetKit

## Build & Run

Xcodeでプロジェクトを開いてビルド:
```bash
open RunRun.xcodeproj
# Cmd+R でシミュレータ/実機で実行
```

HealthKitを使用するため、実機でのテストを推奨。シミュレータではヘルスケアデータがないためモックが必要。

CLIでビルド:
```bash
xcodebuild -project RunRun.xcodeproj -scheme RunRun -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Project Structure

```
RunRun/
├── RunRunApp.swift              # @main エントリポイント
├── ContentView.swift            # タブビュー (Home/Records/Leaderboard/Friends/Settings)
├── Views/
│   ├── Components/
│   │   ├── ShineLogoView.swift          # ローディング用シャインアニメーション
│   │   ├── ChartTooltip.swift           # チャート用ツールチップ
│   │   ├── ExpandableNavigationButtons.swift # ラン詳細の前後/最古/最新ナビゲーション
│   │   ├── GoalProgressView.swift       # 目標達成率の進捗表示
│   │   ├── LiquidGlassModifier.swift    # 半透明グラスエフェクト
│   │   ├── LottieView.swift             # Lottieアニメーション
│   │   ├── PulsingDot.swift             # 同期中などのパルス表示
│   │   ├── RouteThumbnailView.swift     # ルートサムネイル
│   │   ├── ShareSettingsContainer.swift # 共有設定の共通コンテナ
│   │   └── SkeletonView.swift           # ロード中のスケルトンUI
│   ├── TimelineView.swift           # ホーム（タイムライン）
│   ├── YearDetailView.swift         # 年間記録詳細
│   ├── MonthDetailView.swift        # 月の詳細（個別記録一覧）
│   ├── RunDetailView.swift          # ラン詳細
│   ├── WeeklyStatsView.swift        # 週間推移
│   ├── LeaderboardView.swift        # 月別ランキング
│   ├── FriendsView.swift            # フレンド一覧
│   ├── ProfileView.swift            # プロフィール表示
│   ├── ProfileEditView.swift        # プロフィール編集
│   ├── ProfileAvatarView.swift      # アバター表示コンポーネント
│   ├── SettingsView.swift           # 設定画面
│   ├── LoginView.swift              # ログイン画面
│   ├── UserSearchView.swift         # ユーザー検索
│   ├── GoalListView.swift           # 月別・年別目標一覧
│   ├── GoalSettingsView.swift       # 目標の作成・編集
│   ├── SyncBannerView.swift         # 同期状態バナー
│   ├── SyncProgressView.swift       # 同期進捗表示
│   ├── GradientRouteMapView.swift   # ルートマップ表示
│   ├── HeartRateChartView.swift     # 心拍チャート
│   ├── RunCalendarView.swift        # カレンダー表示
│   ├── LicensesView.swift           # ライセンス一覧
│   ├── ShareSheet.swift             # 共有シート
│   ├── RunShareSettingsView.swift   # ラン共有設定
│   ├── MonthShareSettingsView.swift # 月共有設定
│   ├── YearShareSettingsView.swift  # 年共有設定
│   └── ProfileShareSettingsView.swift # プロフィール共有設定
├── ViewModels/
│   ├── TimelineViewModel.swift
│   ├── YearDetailViewModel.swift
│   └── MonthDetailViewModel.swift
├── Models/
│   ├── RunningRecord.swift          # HealthKitから取得したラン記録
│   ├── MonthlyRunningStats.swift    # 月別統計
│   ├── WeeklyRunningStats.swift     # 週別統計
│   ├── YearlyStats.swift            # 年別統計
│   ├── TimelineRun.swift            # タイムライン用ラン記録
│   ├── UserProfile.swift            # ユーザープロフィール
│   ├── FriendRequest.swift          # フレンドリクエスト
│   ├── SyncedRunRecord.swift        # Firestoreに同期した記録
│   ├── HeartRateSample.swift        # 心拍データ
│   ├── RouteSegment.swift           # ルートセグメント
│   ├── SimplifiedRoute.swift        # 簡略化ルート（ウィジェット/共有用）
│   ├── Split.swift                  # スプリットデータ（1km単位）
│   ├── PersonalRecord.swift         # パーソナルレコード（5K/10K/ハーフ/フル）
│   ├── RunningGoal.swift            # 月別・年別の目標
│   └── ScreenType.swift             # 画面遷移タイプ（NavigationPath用）
├── Services/
│   ├── HealthKitService.swift               # HealthKit連携
│   ├── AuthenticationService.swift          # Apple Sign In + Firebase Auth
│   ├── FirestoreService.swift               # Firestore CRUD（コア）
│   ├── FirestoreService+UserProfile.swift   # ユーザープロフィール操作
│   ├── FirestoreService+RunRecords.swift    # ラン記録の同期
│   ├── FirestoreService+Timeline.swift      # タイムライン取得（ページネーション）
│   ├── FirestoreService+Leaderboard.swift   # 月別ランキング集計
│   ├── FirestoreService+Friends.swift       # フレンド機能
│   ├── FirestoreService+Goals.swift         # 目標の保存/取得
│   ├── FirestoreService+Debug.swift         # デバッグ用書き込み
│   ├── StorageService.swift                 # Firebase Storage（アバター画像）
│   ├── SyncService.swift                    # HealthKit→Firestore同期
│   ├── WidgetService.swift                  # ウィジェットデータ更新
│   ├── AnalyticsService.swift               # Firebase Analytics
│   ├── NotificationService.swift            # FCM・ローカル通知
│   ├── BadgeService.swift                   # アプリアイコンバッジ
│   ├── ImageCacheService.swift              # 画像キャッシュ
│   ├── ImageComposerService.swift           # 共有画像生成（HDR対応 HEIF）
│   ├── PhotoLibraryService.swift            # 写真ライブラリ保存
│   ├── RouteCacheService.swift              # ルートセグメントのキャッシュ
│   ├── ReviewService.swift                  # App Storeレビュー要求
│   ├── DebugSettings.swift                  # デバッグ用設定
│   ├── MockDataProvider.swift               # スクリーンショット用モックデータ
│   └── ScreenshotMode.swift                 # スクリーンショットモード
└── Utilities/
    ├── UnitFormatter.swift          # 距離・時間のフォーマット
    └── NavigationAction.swift       # プログラム的ナビゲーション用環境値

RunRunWidget/
├── RunRunWidgetBundle.swift     # ウィジェットバンドル
├── CalendarWidget.swift         # 月間カレンダーウィジェット
├── ProgressWidget.swift         # 累積距離グラフウィジェット
└── WidgetDataStore.swift        # ウィジェット用データストア（App Groups経由）
```

## Architecture Conventions

### MVVM Pattern
- **View**: UIのみを担当。`@StateObject`でViewModelを保持
- **ViewModel**: `@MainActor final class`、`ObservableObject`準拠。ビジネスロジックを担当
- **Model**: 純粋な構造体。`Identifiable`, `Equatable`準拠

### Naming
- View: `〇〇View.swift`
- ViewModel: `〇〇ViewModel.swift`
- Service: `〇〇Service.swift`

## HealthKit Integration

`HealthKitService`がHealthKitとの通信を担当:
- 認証リクエスト: `requestAuthorization()`
- ワークアウト取得: `fetchRunningWorkouts(from:to:)`
- 月別統計: `fetchMonthlyStats(for:)`
- バックグラウンド配信: `enableBackgroundDelivery()` + `startObservingWorkouts()`

Info.plistに`NSHealthShareUsageDescription`が設定済み。

### HKObserverQuery

ランニング終了後にウィジェットを即時更新するため、`HKObserverQuery`でワークアウトの変更を監視:

```swift
healthKitService.startObservingWorkouts {
    // ワークアウト変更時にBGAppRefreshTaskをスケジュール
    scheduleWidgetRefresh()
}
```

## Widget Integration

### アーキテクチャ

```
[メインアプリ] → [WidgetService] → [App Groups UserDefaults] → [WidgetDataStore] → [Widget]
```

- **WidgetService**: メインアプリからウィジェットデータを保存
- **WidgetDataStore**: ウィジェットからデータを読み込み
- **App Groups**: `group.com.himatsubu.RunRun`でデータ共有

### ウィジェット種類

| ウィジェット | サイズ | 説明 |
|-------------|--------|------|
| CalendarWidget | Small/Medium/Large | 月間カレンダーでランした日をマーク |
| ProgressWidget | Medium | 累積距離グラフ（当月 vs 前月） |

### 更新タイミング

1. **アプリ起動時**: `SyncService`が同期後に`WidgetService.updateFromRecords()`を呼び出し
2. **バックグラウンド更新**: `BGAppRefreshTask`で定期更新（15分間隔）
3. **HealthKit変更検知**: `HKObserverQuery`で即時更新

## Firebase Integration

### Authentication
- Sign in with Apple を使用
- `AuthenticationService`が認証状態を管理
- 初回サインイン時にFirestoreにユーザープロフィールを作成

### Firestore
- データベース: `(default)` (asia-northeast1)
- コレクション:
  - `users`: ユーザープロフィール (displayName, email, createdAt)
  - `runs`: ランニング記録 (userId, date, distanceKm, durationSeconds)

**注意**: FirestoreのCodableは問題が起きやすいため、辞書ベースでデータを読み書きする。

### Firebase CLI
```bash
# デプロイ
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### Analytics

`AnalyticsService`がFirebase Analyticsへのイベント送信を担当。

#### スクリーン計測

`.analyticsScreen("ScreenName")` ViewModifierで自動計測:

| 画面 | スクリーン名 |
|-----|-------------|
| タイムライン | Timeline |
| ランキング | Leaderboard |
| フレンド | Friends |
| 設定 | Settings |
| プロフィール | Profile |
| プロフィール編集 | ProfileEdit |
| 年詳細 | YearDetail |
| 月詳細 | MonthDetail |
| ラン詳細 | RunDetail |
| 週間推移 | WeeklyStats |
| ユーザー検索 | UserSearch |
| ログイン | Login |
| ライセンス | Licenses |
| 共有設定 | ShareSettings, MonthShareSettings, YearShareSettings, ProfileShareSettings |

#### イベント計測

| イベント名 | 説明 | パラメータ |
|-----------|------|-----------|
| `sign_up` | 新規登録 | method: "apple" |
| `login` | ログイン | method: "apple" |
| `logout` | ログアウト | - |
| `delete_account` | 退会 | - |
| `sync_completed` | 同期完了 | record_count |
| `sync_error` | 同期エラー | error |
| `update_profile` | プロフィール更新 | has_photo, icon |
| `view_run_detail` | ラン詳細表示 | distance_km, duration_minutes |
| `send_friend_request` | フレンド申請 | - |
| `accept_friend_request` | フレンド承認 | - |
| `reject_friend_request` | フレンド拒否 | - |
| `remove_friend` | フレンド解除 | - |
| `change_distance_unit` | 単位変更 | unit: "km" or "mi" |
| `share_image_saved` | 画像保存（ラン） | show_* オプション |
| `share_image_shared` | 画像共有（ラン） | show_* オプション |
| `month_share_image_saved` | 画像保存（月） | show_* オプション |
| `month_share_image_shared` | 画像共有（月） | show_* オプション |
| `year_share_image_saved` | 画像保存（年） | show_* オプション |
| `year_share_image_shared` | 画像共有（年） | show_* オプション |
| `profile_share_image_saved` | 画像保存（プロフィール） | show_* オプション |
| `profile_share_image_shared` | 画像共有（プロフィール） | show_* オプション |

## Goals (目標管理)

`RunningGoal` で月別・年別の走行距離目標を管理。Firestoreに保存（`FirestoreService+Goals`）。

- `GoalListView`: 月別・年別の目標一覧
- `GoalSettingsView`: 目標の作成・編集・削除
- `GoalProgressView`: 達成率の進捗バー（タイムライン・年詳細・月詳細で表示）

## Personal Records

`PersonalRecord` で 5K / 10K / ハーフマラソン / フルマラソン相当の最速タイムを管理。`RunDetailView` で該当ランがPRかどうかを表示。

## Image Sharing (HDR対応)

`ImageComposerService` で共有画像を生成:
- フォーマット: HEIF
- カラースペース: Display P3
- HDRゲインマップ保持（対応端末でHDR表示）
- アスペクト比: 1:1, 4:5, 9:16
- 表示要素のオン/オフ切替（日付、距離、ペース、心拍、ルート、カロリーなど）

## Notifications & Badges

- **FCM**: `NotificationService` でFirebase Cloud Messagingトークンを管理
- **ローカル通知**: 新規ラン同期、フレンドリクエスト、フレンド承認
- **ディープリンク**: 通知タップでタブ遷移・ラン詳細表示
- **アプリアイコンバッジ**: `BadgeService` が未読フレンドリクエスト数・新規フレンド数を集計

## Xcode Project Setup

新規Xcodeプロジェクト作成時:
1. File > New > Project > iOS App
2. Product Name: `RunRun`
3. Interface: SwiftUI, Language: Swift
4. Signing & Capabilities で「HealthKit」「Sign in with Apple」「Background Modes」「App Groups」を追加
5. Firebase SDKをSwift Package Managerで追加

## Screenshots & App Store Metadata

### スクリーンショット撮影

`--screenshots`フラグでアプリを起動するとスクリーンショットモードになり、`MockDataProvider`のモックデータで全画面が表示される。

#### 自動撮影
- テストファイル: `RunRunUITests/ScreenshotTests.swift`
- 撮影設定: `fastlane/Snapfile`（デバイス・言語）
- 画面一覧: 01_Timeline, 02_Records, 03_MonthDetail, 04_RunDetail, 05_FullMap, 06_Leaderboard

#### ウィジェット（手動）
- 配置先: `fastlane/screenshots-manual/{ja,en-US}/`
- ファイル名: `{デバイス名}-{番号}_{名前}.png`

#### フレーム・テキスト
- フレーム設定: `fastlane/screenshots/Framefile.json`
- キーワード: `fastlane/screenshots/{lang}/keyword.strings`
- タイトル: `fastlane/screenshots/{lang}/title.strings`
- 背景画像: `fastlane/screenshots/background.png`

#### Fastlaneレーン一覧

| レーン | 説明 |
|-------|------|
| `marketing_screenshots` | 全工程（撮影→手動コピー→フレーム追加） |
| `add_frames` | フレーム追加+圧縮+プレビュー生成 |
| `upload_screenshots` | スクショのみApp Store Connectにアップロード |
| `upload_metadata` | メタデータ+スクショをアップロード |
| `download_metadata` | App Store Connectからダウンロード |
| `generate_preview` | プレビューHTML生成 |

### メタデータ

App Storeのテキスト情報は `fastlane/metadata/{ja,en-US}/` に保存:
- `description.txt` - アプリ説明文
- `release_notes.txt` - リリースノート
- `keywords.txt` - 検索キーワード
- `subtitle.txt` - サブタイトル

### ランディングページ

- 日本語: `docs/`、英語: `docs/en/`
- GitHub Pagesで自動デプロイ（mainへのpush時、docs/変更で発火）
- スクショ更新時: `./scripts/update-landing-assets.sh` でframed画像をdocs/assets/にコピー

## Git Workflow

### ブランチ戦略
- `main`: プロダクションブランチ
- `feature/*`: 機能追加用ブランチ
- **mainへの直接プッシュ禁止**: 全ての変更はPR経由でマージする

### PR・マージルール
```bash
# PRをマージしてブランチを削除
gh pr merge <PR番号> --merge --delete-branch
```

- **`--squash`は使用禁止**: 個別のコミット履歴を残すため、必ず`--merge`を使用する
- `--delete-branch`でマージすると、ローカルのmainも自動的に更新される。マージ後に`git checkout main && git pull`は不要

### コミット・PR作成時のルール
- コミットメッセージは日本語で書く
- PRのタイトル・本文も日本語で書く
- Co-Authored-Byの署名は付けない

### リリース（GitHub Actions）

#### TestFlightへのアップロード
GitHub Actionsの「Release to App Store」ワークフローを手動実行:
1. GitHub → Actions → 「Release to App Store」 → 「Run workflow」
2. ビルド完了後、自動で`build-N`タグが作成される
3. TestFlightで審査後、App Storeに提出

#### App Storeメタデータの更新
リリースノートやスクリーンショットの更新:
```bash
# ローカルでメタデータを更新
bundle exec fastlane upload_metadata

# または GitHub Actions で実行
# Actions → 「Update App Store Assets」 → 「Run workflow」
```

メタデータファイル:
- `fastlane/metadata/ja/release_notes.txt` - 日本語リリースノート
- `fastlane/metadata/en-US/release_notes.txt` - 英語リリースノート
- `fastlane/metadata/ja/description.txt` - 日本語説明文
- `fastlane/metadata/en-US/description.txt` - 英語説明文

#### 必要なSecrets
- `ASC_ISSUER_ID` - App Store Connect API Issuer ID
- `ASC_KEY_ID` - App Store Connect API Key ID
- `ASC_PRIVATE_KEY` - App Store Connect API Private Key
- `DISTRIBUTION_CERTIFICATE_P12` - 配布用証明書（Base64）
- `DISTRIBUTION_CERTIFICATE_PASSWORD` - 証明書パスワード
- `PROVISIONING_PROFILE` - メインアプリ用プロビジョニングプロファイル
- `WIDGET_PROVISIONING_PROFILE` - ウィジェット用プロビジョニングプロファイル
