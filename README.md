# RunRun

Apple Watchのランニング記録を月別に表示し、他のユーザーとランキングで競えるiOSアプリ。

## CI/CD

タグをプッシュするとGitHub ActionsがTestFlightに自動アップロードします。

```bash
git tag v1.0.0
git push origin v1.0.0
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
