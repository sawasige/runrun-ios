# RunRun

Apple Watchのランニング記録を月別に表示し、他のユーザーとランキングで競えるiOSアプリ。

## CI/CD

### ワークフロー一覧

| ワークフロー | トリガー | 説明 |
|------------|---------|------|
| Release to App Store | 手動実行 | ビルド→TestFlightにアップロード |
| Update App Store Assets | 手動実行 | スクリーンショット撮影・メタデータ更新 |

### リリース手順

GitHub Actionsの「Release to App Store」ワークフローを手動実行します。

```bash
gh workflow run "Release to App Store"
```

または GitHub Actions ページから「Run workflow」ボタンで実行。

- ビルド番号は `run_number` で自動インクリメント
- 成功時に `build-{run_number}` タグが自動作成される

### App Store アセット更新

スクリーンショットやメタデータの更新はローカルで実行してください（CI実行は時間がかかるため）。

```bash
# スクリーンショット撮影
bundle exec fastlane screenshots

# フレーム追加
bundle exec fastlane add_frames

# App Store Connectにアップロード
bundle exec fastlane upload_screenshots
bundle exec fastlane upload_metadata
```

### 年1回の証明書・プロファイル更新手順

Distribution証明書とプロビジョニングプロファイルは1年で期限切れになります。以下の手順で更新してください。

#### 1. Distribution証明書の更新

1. [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list) にアクセス
2. Certificates → 「+」ボタン → 「Apple Distribution」を選択
3. CSRをアップロードして証明書を作成
4. 証明書をダウンロードしてキーチェーンにインストール
5. キーチェーンアクセスで証明書を右クリック →「書き出す」→ p12形式で保存
6. Base64エンコード:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
7. GitHub Secretsの `DISTRIBUTION_CERTIFICATE_P12` を更新
8. パスワードを変更した場合は `DISTRIBUTION_CERTIFICATE_PASSWORD` も更新

#### 2. プロビジョニングプロファイルの更新

1. [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list) にアクセス
2. Profiles → 「RunRun Distribution」を選択 → 「Edit」
3. 新しい証明書を選択して「Save」
4. プロファイルをダウンロード
5. Base64エンコード:
   ```bash
   base64 -i RunRun_Distribution.mobileprovision | pbcopy
   ```
6. GitHub Secretsの `PROVISIONING_PROFILE` を更新

#### 必要なSecrets一覧

| Secret | 説明 | 更新頻度 |
|--------|------|----------|
| `DISTRIBUTION_CERTIFICATE_P12` | Distribution証明書（Base64） | 年1回 |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | p12のパスワード | 証明書更新時（任意） |
| `PROVISIONING_PROFILE` | プロビジョニングプロファイル（Base64） | 年1回 |
| `ASC_KEY_ID` | App Store Connect APIキーID | 期限なし |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID | 期限なし |
| `ASC_PRIVATE_KEY` | App Store Connect APIキー（p8） | 期限なし |

## Cloud Functions

プッシュ通知の送信にFirebase Cloud Functionsを使用しています。

### デプロイ方法

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 関数一覧

| 関数名 | トリガー | 説明 |
|--------|----------|------|
| `onFriendRequestCreated` | Firestoreトリガー | フレンドリクエスト作成時に受信者へ通知 |
| `onFriendRequestAccepted` | Firestoreトリガー | フレンドリクエスト承認時に送信者へ通知 |
| `sendTestNotification` | HTTPSコール | テスト通知送信（DEBUGビルドのみ使用） |

### ログ確認

```bash
firebase functions:log
```

## Analytics

Firebase Analyticsでユーザー行動を計測しています。

### スクリーン (screen_view)

| Screen Name | 画面 | ファイル |
|-------------|------|---------|
| `Login` | ログイン画面 | LoginView.swift |
| `Timeline` | ホーム（タイムライン） | TimelineView.swift |
| `YearlyRecords` | 年間記録 | YearlyRecordsView.swift |
| `MonthDetail` | 月の詳細 | MonthDetailView.swift |
| `RunDetail` | ラン詳細 | RunDetailView.swift |
| `WeeklyStats` | 週間推移 | WeeklyStatsView.swift |
| `Leaderboard` | ランキング | LeaderboardView.swift |
| `Friends` | フレンド一覧 | FriendsView.swift |
| `UserSearch` | ユーザー検索 | UserSearchView.swift |
| `Profile` | プロフィール | ProfileView.swift |
| `ProfileEdit` | プロフィール編集 | ProfileEditView.swift |
| `Settings` | 設定 | SettingsView.swift |
| `Licenses` | ライセンス | LicensesView.swift |

### イベント (logEvent)

| Event Name | 説明 | パラメータ |
|------------|------|-----------|
| `login` | ログイン成功 | `method`: "apple" |
| `logout` | ログアウト | - |
| `sync_completed` | データ同期完了 | `synced_count`: 同期件数 |
| `view_run_detail` | ラン詳細閲覧 | `distance_km`, `duration_seconds` |
| `update_profile` | プロフィール更新 | `changed_avatar`, `changed_icon` |
| `send_friend_request` | フレンド申請送信 | - |
| `accept_friend_request` | フレンド申請承認 | - |

### 使い方

画面に計測を追加する場合:

```swift
.analyticsScreen("ScreenName")
```

イベントを送信する場合:

```swift
AnalyticsService.logEvent("event_name", parameters: ["key": "value"])
```

## 配信エリア拡大計画

英語対応・マイル対応を完了したため、日本以外の地域への配信を段階的に拡大します。

### 現在の配信エリア

- 日本
- オーストラリア
- ニュージーランド

### 拡大スケジュール

| Phase | 地域 | 理由 | ステータス |
|-------|------|------|-----------|
| 1 | オーストラリア、ニュージーランド | 英語圏、法規制が緩やか、時差少ない | **配信中** (2026-01-12) |
| 2 | シンガポール | 英語通用、テック先進国、アジア時間帯 | 未対応 |
| 3 | アメリカ、カナダ | 英語、マイル使用、大市場 | 未対応 |
| 4 | イギリス | 英語、マイル使用 | 未対応 |

### 配信エリアの設定方法

fastlane deliverは配信地域の設定をサポートしていないため、App Store Connectで手動設定が必要です。

1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. 「マイApp」→「RunRun」を選択
3. 「価格および配信状況」タブを開く
4. 「Appの利用可能状況」セクションで国/地域を追加

### メタデータについて

- 追加地域用のメタデータ（説明文、キーワード等）は `en-US` にフォールバック
- 地域固有のキーワード最適化が必要な場合は `fastlane/metadata/` に `en-AU`、`en-GB` 等のディレクトリを作成
