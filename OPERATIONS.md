# 運用手順

## ユーザー通報への対応

アプリの他人のプロフィール画面 > 「…」メニュー > 「通報」から送られた通報は、Firestore の `reports` コレクションに保存される。
クライアントからは作成しかできないため、確認と対応は Firebase コンソールで行う。

- コンソール: https://console.firebase.google.com/project/runrun-66f12/firestore/databases/-default-/data/~2Freports
- App Store 審査ガイドライン 1.2 の趣旨に沿い、**通報から 24 時間以内に一次対応**する

### ドキュメントの内容

| フィールド | 内容 |
|-----------|------|
| `reporterId` | 通報したユーザーの UID |
| `reportedUserId` | 通報されたユーザーの UID |
| `reportedDisplayName` | 通報時点の表示名（その後変更されても確認できる） |
| `reason` | `inappropriate_name` / `inappropriate_photo` / `harassment` / `spam` / `other` |
| `details` | 任意の補足（最大 500 文字） |
| `status` | `open`（未対応）。対応後に手動で `resolved` または `dismissed` にする |
| `createdAt` | 通報日時 |

### 手順

1. コンソールで `reports` を開き、`status == open` でフィルタする
2. `reportedUserId` の `users/{uid}` を開き、表示名・アバター画像を確認する。`reason` が `harassment` / `spam` の場合は `friendRequests` で `fromUserId == reportedUserId` の申請の頻度も見る
3. 利用規約（docs/terms.html「禁止事項」）に該当するか判断する
4. 該当する場合の対応（軽い順）
   - **表示名**: `users/{uid}.displayName` を `Runner` に書き換える（コンソールからの編集はセキュリティルールの対象外）
   - **アバター画像**: `users/{uid}.avatarURL` フィールドを削除し、Storage の `avatars/{uid}/` 配下を削除する
   - **繰り返し・悪質**: Authentication でそのユーザーを「無効化」する。データごと消す場合は Authentication からユーザーを削除すると `onUserDeleted` が関連データを削除する
5. `reports` のドキュメントに以下を追記して閉じる
   - `status`: `resolved`（対応した）または `dismissed`（該当なし）
   - `resolvedAt`: 対応日時
   - `note`: 何をしたか一言
6. 同じ `reportedUserId` に対する他の `open` な通報も同時に処理する

### 補足

- 通報者・被通報者のどちらにも通知は送らない。アプリ側でもその旨を案内している
- 被通報者が「自分の通報」を見る手段はない（`reports` は読み取り不可）
- 新規通報の自動通知は未実装。定期的にコンソールを確認するか、必要になったら `onReportCreated` の Cloud Function で運営端末へプッシュする
