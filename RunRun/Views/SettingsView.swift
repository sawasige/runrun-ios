import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var isSyncing = false
    @State private var lastSyncMessage: String?
    @State private var userProfile: UserProfile?
    @State private var showingProfileEdit = false
    @State private var debugMessage: String?

    private let firestoreService = FirestoreService()
    private let healthKitService = HealthKitService()

    var body: some View {
        NavigationStack {
            List {
                Section("プロフィール") {
                    HStack {
                        Text("表示名")
                        Spacer()
                        Text(userProfile?.displayName ?? "読み込み中...")
                            .foregroundStyle(.secondary)
                    }

                    Button("プロフィールを編集") {
                        showingProfileEdit = true
                    }
                }

                Section("アカウント") {
                    if let email = authService.user?.email {
                        HStack {
                            Text("メール")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("サインアウト", role: .destructive) {
                        try? authService.signOut()
                    }
                }

                Section("データ同期") {
                    Button {
                        syncData()
                    } label: {
                        HStack {
                            Text("クラウドに同期")
                            Spacer()    
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)

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
                }

                #if DEBUG
                Section("デバッグ") {
                    Button("ダミーユーザーを作成") {
                        Task { await createDummyData() }
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
                        currentDisplayName: userProfile?.displayName ?? ""
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

    private func syncData() {
        guard let userId = authService.user?.uid else { return }

        isSyncing = true
        lastSyncMessage = nil

        Task {
            do {
                let calendar = Calendar.current
                let now = Date()
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

                let records = try await healthKitService.fetchRunningWorkouts(from: startOfMonth, to: now)
                let newCount = try await firestoreService.syncRunRecords(userId: userId, records: records)

                // 今月の統計情報を更新
                let allRuns = try await firestoreService.getUserRuns(userId: userId)
                let monthlyRuns = allRuns.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
                let totalDistance = monthlyRuns.reduce(0) { $0 + $1.distanceKm }
                try await firestoreService.updateUserStats(
                    userId: userId,
                    totalDistanceKm: totalDistance,
                    totalRuns: monthlyRuns.count
                )

                if newCount > 0 {
                    lastSyncMessage = "\(newCount)件の新規記録を同期しました"
                } else {
                    lastSyncMessage = "同期済みです"
                }
            } catch {
                lastSyncMessage = "同期エラー: \(error.localizedDescription)"
            }

            isSyncing = false
        }
    }

    #if DEBUG
    private func createDummyData() async {
        guard let currentUserId = authService.user?.uid else { return }

        debugMessage = "作成中..."

        do {
            // ダミーユーザーを作成
            let dummyUsers = [
                ("dummy1", "田中太郎", 85.5, 12),
                ("dummy2", "鈴木花子", 120.3, 18),
                ("dummy3", "佐藤次郎", 45.2, 8),
                ("dummy4", "山田美咲", 200.0, 25),
                ("dummy5", "高橋健一", 65.8, 10)
            ]

            for (id, name, distance, runs) in dummyUsers {
                try await firestoreService.createUserProfile(
                    userId: id,
                    displayName: name,
                    email: "\(id)@example.com"
                )
                try await firestoreService.updateUserStats(
                    userId: id,
                    totalDistanceKm: distance,
                    totalRuns: runs
                )

                // 今月のダミーラン記録を作成
                try await firestoreService.createDummyRun(
                    userId: id,
                    distanceKm: distance / Double(runs),
                    date: Date()
                )
            }

            // 自分にフレンドリクエストを送信
            for (id, name, _, _) in dummyUsers.prefix(2) {
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
