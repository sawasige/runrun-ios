# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RunRunはApple Watchのランニング記録を月別に表示するiOSアプリ。将来的にはソーシャル機能を追加予定。

## Tech Stack

- **UI**: SwiftUI (iOS 17+)
- **Architecture**: MVVM
- **Data Source**: HealthKit (Apple Watchの運動データ)
- **Backend (将来)**: Firebase

## Build & Run

Xcodeでプロジェクトを開いてビルド:
```bash
open RunRun.xcodeproj
# Cmd+R でシミュレータ/実機で実行
```

HealthKitを使用するため、実機でのテストを推奨。シミュレータではヘルスケアデータがないためモックが必要。

## Project Structure

```
RunRun/
├── Sources/
│   ├── App/           # @main エントリポイント、ContentView
│   ├── Views/         # SwiftUI View (画面)
│   ├── ViewModels/    # @MainActor ObservableObject
│   ├── Models/        # データ構造体
│   └── Services/      # HealthKit等の外部連携
└── Resources/
    ├── Info.plist     # HealthKit権限設定含む
    └── Assets.xcassets/
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

## Xcode Project Setup

新規Xcodeプロジェクト作成時:
1. File > New > Project > iOS App
2. Product Name: `RunRun`
3. Interface: SwiftUI, Language: Swift
4. Signing & Capabilities で「HealthKit」を追加
5. HealthKit の「Clinical Health Records」はオフ、「Background Delivery」は任意
