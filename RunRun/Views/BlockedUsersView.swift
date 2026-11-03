import SwiftUI
import FirebaseAuth

/// ブロックしたユーザーの一覧（設定画面からナビゲーション）
struct BlockedUsersView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var blockedUsers: [UserProfile] = []
    @State private var isLoading = true
    @State private var processingUserIds: Set<String> = []

    private let firestoreService = FirestoreService.shared

    var body: some View {
        List {
            if isLoading && blockedUsers.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if blockedUsers.isEmpty {
                ContentUnavailableView(
                    "No Blocked Users",
                    systemImage: "person.slash",
                    description: Text("Users you block won't appear in rankings or search and can't send you friend requests.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(blockedUsers) { user in
                        HStack(spacing: 12) {
                            ProfileAvatarView(user: user, size: 40)
                            Text(user.displayName)
                                .font(.headline)
                            Spacer()
                            Button("Unblock") {
                                Task { await unblock(user) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(processingUserIds.contains(user.id ?? ""))
                        }
                    }
                } footer: {
                    Text("Users you block won't appear in rankings or search and can't send you friend requests.")
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen("BlockedUsers")
        .task {
            await loadBlockedUsers()
        }
    }

    private func loadBlockedUsers() async {
        guard let userId = authService.user?.uid else { return }
        do {
            blockedUsers = try await firestoreService.getBlockedProfiles(userId: userId)
        } catch {
            print("Load blocked users error: \(error)")
        }
        isLoading = false
    }

    private func unblock(_ user: UserProfile) async {
        guard let currentUserId = authService.user?.uid,
              let blockedUserId = user.id else { return }

        processingUserIds.insert(blockedUserId)
        defer { processingUserIds.remove(blockedUserId) }

        do {
            try await firestoreService.unblockUser(currentUserId: currentUserId, blockedUserId: blockedUserId)
            AnalyticsService.logEvent("unblock_user")
            withAnimation {
                blockedUsers.removeAll { $0.id == blockedUserId }
            }
        } catch {
            print("Unblock error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environmentObject(AuthenticationService())
    }
}
