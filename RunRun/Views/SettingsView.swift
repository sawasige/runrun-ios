import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var syncService: SyncService
    @State private var lastSyncMessage: String?
    @State private var userProfile: UserProfile?
    @State private var showingProfileEdit = false
    @State private var debugMessage: String?

    private let firestoreService = FirestoreService.shared

    var body: some View {
        NavigationStack {
            List {
                Section("プロフィール") {
                    HStack(spacing: 16) {
                        ProfileAvatarView(
                            iconName: userProfile?.iconName ?? "figure.run",
                            avatarURL: userProfile?.avatarURL,
                            size: 50
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userProfile?.displayName ?? "読み込み中...")
                                .font(.headline)
                            if let email = authService.user?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Button("プロフィールを編集") {
                        showingProfileEdit = true
                    }
                }

                Section("アカウント") {
                    Button("サインアウト", role: .destructive) {
                        try? authService.signOut()
                    }
                }

                Section("データ同期") {
                    Button {
                        Task { await syncData() }
                    } label: {
                        HStack {
                            Text("再同期")
                            Spacer()
                            if syncService.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(syncService.isSyncing)

                    if let message = lastSyncMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("ヘルスケア") {
                    Button("ヘルスケア設定を開く") {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("利用規約", destination: URL(string: "https://sawasige.github.io/runrun-ios/terms.html")!)

                    Link("プライバシーポリシー", destination: URL(string: "https://sawasige.github.io/runrun-ios/privacy.html")!)

                    Link("サポート", destination: URL(string: "https://sawasige.github.io/runrun-ios/support.html")!)

                    NavigationLink("ライセンス") {
                        LicensesView()
                    }
                }

                #if DEBUG
                Section("デバッグ") {
                    Button("テスト通知を送信") {
                        Task { await sendTestNotification() }
                    }

                    Button("ダミーユーザーを作成") {
                        Task { await createDummyData() }
                    }

                    Button("Crashlyticsテスト", role: .destructive) {
                        fatalError("Crashlytics test crash")
                    }

                    if let message = debugMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                #endif
            }
            .navigationTitle("設定")
            .task {
                await loadProfile()
            }
            .sheet(isPresented: $showingProfileEdit, onDismiss: {
                Task { await loadProfile() }
            }) {
                if let userId = authService.user?.uid {
                    ProfileEditView(
                        userId: userId,
                        currentDisplayName: userProfile?.displayName ?? "",
                        currentIcon: userProfile?.iconName ?? "figure.run",
                        currentAvatarURL: userProfile?.avatarURL
                    )
                }
            }
        }
    }

    private func loadProfile() async {
        guard let userId = authService.user?.uid else { return }

        do {
            if let profile = try await firestoreService.getUserProfile(userId: userId) {
                userProfile = profile
            } else {
                // プロフィールが存在しない場合は作成
                let displayName = authService.user?.displayName ?? "ランナー"
                try await firestoreService.createUserProfile(
                    userId: userId,
                    displayName: displayName,
                    email: authService.user?.email
                )
                userProfile = try await firestoreService.getUserProfile(userId: userId)
            }
        } catch {
            print("Profile load error: \(error)")
        }
    }

    private func syncData() async {
        guard let userId = authService.user?.uid else { return }

        lastSyncMessage = nil
        await syncService.syncHealthKitData(userId: userId)

        if let error = syncService.error {
            lastSyncMessage = "同期エラー: \(error.localizedDescription)"
        } else if syncService.syncedCount > 0 {
            lastSyncMessage = "\(syncService.syncedCount)件の新規記録を同期しました"
        } else {
            lastSyncMessage = "同期済みです"
        }
    }

    #if DEBUG
    private func sendTestNotification() async {
        debugMessage = "送信中..."

        let functions = Functions.functions(region: "asia-northeast1")
        do {
            let result = try await functions.httpsCallable("sendTestNotification").call()
            if let data = result.data as? [String: Any],
               let message = data["message"] as? String {
                debugMessage = message
            } else {
                debugMessage = "通知を送信しました"
            }
        } catch {
            debugMessage = "エラー: \(error.localizedDescription)"
        }
    }

    private func createDummyData() async {
        guard let currentUserId = authService.user?.uid else { return }

        debugMessage = "作成中..."

        do {
            // ダミーユーザーを作成
            let dummyUsers = [
                ("dummy1", "田中太郎", 8.5),
                ("dummy2", "鈴木花子", 12.3),
                ("dummy3", "佐藤次郎", 4.5),
                ("dummy4", "山田美咲", 15.0),
                ("dummy5", "高橋健一", 6.8)
            ]

            for (id, name, distance) in dummyUsers {
                try await firestoreService.createUserProfile(
                    userId: id,
                    displayName: name,
                    email: "\(id)@example.com"
                )

                // 今月のダミーラン記録を作成
                try await firestoreService.createDummyRun(
                    userId: id,
                    distanceKm: distance,
                    date: Date()
                )
            }

            // 自分にフレンドリクエストを送信
            for (id, name, _) in dummyUsers.prefix(2) {
                try await firestoreService.sendFriendRequest(
                    fromUserId: id,
                    fromDisplayName: name,
                    toUserId: currentUserId
                )
            }

            debugMessage = "ダミーユーザー5人とリクエスト2件を作成しました"
        } catch {
            debugMessage = "エラー: \(error.localizedDescription)"
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
