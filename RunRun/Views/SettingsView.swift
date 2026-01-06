import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var syncService: SyncService
    @State private var lastSyncMessage: String?
    @State private var userProfile: UserProfile?
    @State private var showingProfileEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var debugMessage: String?

    private let firestoreService = FirestoreService.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack(spacing: 16) {
                        ProfileAvatarView(
                            iconName: userProfile?.iconName ?? "figure.run",
                            avatarURL: userProfile?.avatarURL,
                            size: 50
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userProfile?.displayName ?? String(localized: "Loading..."))
                                .font(.headline)
                            if let email = authService.user?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Button("Edit Profile") {
                        showingProfileEdit = true
                    }
                }

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("Delete Account")
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeleting)

                    if let error = deleteError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Data Sync") {
                    Button {
                        Task { await syncData() }
                    } label: {
                        HStack {
                            Text("Re-sync")
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

                Section("HealthKit") {
                    Button("Open Health Settings") {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Terms of Service", destination: URL(string: "https://sawasige.github.io/runrun-ios/terms.html")!)

                    Link("Privacy Policy", destination: URL(string: "https://sawasige.github.io/runrun-ios/privacy.html")!)

                    Link("Support", destination: URL(string: "https://sawasige.github.io/runrun-ios/support.html")!)

                    NavigationLink("Licenses") {
                        LicensesView()
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Button("Send Test Notification") {
                        Task { await sendTestNotification() }
                    }

                    Button("Create Dummy Users") {
                        Task { await createDummyData() }
                    }

                    Button("Crashlytics Test", role: .destructive) {
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
            .navigationTitle("Settings")
            .task {
                await loadProfile()
            }
            .onAppear {
                AnalyticsService.logScreenView("Settings")
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
            .alert("Confirm Account Deletion", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Deleting your account will permanently remove all your data and cannot be undone. Are you sure?")
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil

        do {
            // 再認証してからアカウント削除（Sign in with Appleの確認画面が表示される）
            try await authService.reauthenticateAndDeleteAccount()
            // 削除成功後、AuthServiceが自動的にサインアウト状態になる
        } catch {
            deleteError = String(localized: "Failed to delete account") + ": \(error.localizedDescription)"
        }

        isDeleting = false
    }

    private func loadProfile() async {
        guard let userId = authService.user?.uid else { return }

        do {
            if let profile = try await firestoreService.getUserProfile(userId: userId) {
                userProfile = profile
            } else {
                // プロフィールが存在しない場合は作成
                let displayName = authService.user?.displayName ?? String(localized: "Runner")
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
            lastSyncMessage = String(localized: "Sync error") + ": \(error.localizedDescription)"
        } else if syncService.syncedCount > 0 {
            lastSyncMessage = String(format: String(localized: "%d new records synced"), syncService.syncedCount)
        } else {
            lastSyncMessage = String(localized: "Already synced")
        }
    }

    #if DEBUG
    private func sendTestNotification() async {
        debugMessage = "Sending..."

        let functions = Functions.functions(region: "asia-northeast1")
        do {
            let result = try await functions.httpsCallable("sendTestNotification").call()
            if let data = result.data as? [String: Any],
               let message = data["message"] as? String {
                debugMessage = message
            } else {
                debugMessage = "Notification sent"
            }
        } catch {
            debugMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func createDummyData() async {
        guard let currentUserId = authService.user?.uid else { return }

        debugMessage = "Creating..."

        do {
            // ダミーユーザーを作成
            let dummyUsers = [
                ("dummy1", "Taro Tanaka", 8.5),
                ("dummy2", "Hanako Suzuki", 12.3),
                ("dummy3", "Jiro Sato", 4.5),
                ("dummy4", "Misaki Yamada", 15.0),
                ("dummy5", "Kenichi Takahashi", 6.8)
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

            // 自分にフレンドリクエストを送信（レート制限なし）
            for (id, name, _) in dummyUsers.prefix(2) {
                try await firestoreService.createDummyFriendRequest(
                    fromUserId: id,
                    fromDisplayName: name,
                    toUserId: currentUserId
                )
            }

            debugMessage = "Created 5 dummy users and 2 requests"
        } catch {
            debugMessage = "Error: \(error.localizedDescription)"
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
