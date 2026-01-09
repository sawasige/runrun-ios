# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RunRunはApple Watchのランニング記録を月別に表示し、他のユーザーとランキングで競えるiOSアプリ。

## Tech Stack

- **UI**: SwiftUI (iOS 17+)
- **Architecture**: MVVM
- **Data Source**: HealthKit (Apple Watchの運動データ)
- **Backend**: Firebase (Authentication, Firestore)
- **認証**: Sign in with Apple

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
├── RunRunApp.swift          # @main エントリポイント
├── ContentView.swift        # タブビュー (記録/ランキング/設定)
├── Views/
│   ├── YearlyRecordsView.swift    # 年間記録
│   ├── MonthDetailView.swift      # 月の詳細 (個別記録一覧)
│   ├── LeaderboardView.swift      # 月別ランキング
│   ├── SettingsView.swift         # 設定画面
│   ├── ProfileEditView.swift      # プロフィール編集
│   └── LoginView.swift            # ログイン画面
├── ViewModels/
│   ├── YearlyRecordsViewModel.swift
│   └── MonthDetailViewModel.swift
├── Models/
│   ├── RunningRecord.swift        # HealthKitから取得したラン記録
│   ├── MonthlyRunningStats.swift  # 月別統計
│   ├── UserProfile.swift          # ユーザープロフィール
│   └── SyncedRunRecord.swift      # Firestoreに同期した記録
└── Services/
    ├── HealthKitService.swift     # HealthKit連携
    ├── AuthenticationService.swift # Apple Sign In + Firebase Auth
    └── FirestoreService.swift     # Firestore CRUD操作
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

Info.plistに`NSHealthShareUsageDescription`が設定済み。

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

## Xcode Project Setup

新規Xcodeプロジェクト作成時:
1. File > New > Project > iOS App
2. Product Name: `RunRun`
3. Interface: SwiftUI, Language: Swift
4. Signing & Capabilities で「HealthKit」「Sign in with Apple」を追加
5. Firebase SDKをSwift Package Managerで追加

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

### リリース（GitHub Actions）
タグをプッシュするとGitHub ActionsがTestFlightに自動アップロードする:
```bash
git tag v1.0.0
git push origin v1.0.0
```

- ビルド番号は `run_number` で自動インクリメント
- App Store Connect APIで自動署名（証明書のエクスポート不要）
- 必要なSecrets: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY`
