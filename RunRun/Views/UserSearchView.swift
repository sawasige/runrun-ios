import SwiftUI
import FirebaseAuth

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var sentRequests: Set<String> = []
    @State private var existingFriends: Set<String> = []

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    Text("ユーザーが見つかりません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults) { user in
                        UserSearchRow(
                            user: user,
                            isFriend: existingFriends.contains(user.id ?? ""),
                            requestSent: sentRequests.contains(user.id ?? ""),
                            onSendRequest: { await sendRequest(to: user) }
                        )
                    }
                }
            }
            .overlay {
                if isSearching {
                    ProgressView()
                }
            }
            .navigationTitle("ユーザー検索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "表示名で検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) {
                Task { await search() }
            }
            .task {
                await loadExistingFriends()
            }
        }
    }

    private func loadExistingFriends() async {
        guard let userId = authService.user?.uid else { return }
        do {
            let friendIds = try await firestoreService.getFriends(userId: userId)
            existingFriends = Set(friendIds)
        } catch {
            print("Load friends error: \(error)")
        }
    }

    private func search() async {
        guard let userId = authService.user?.uid else { return }
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            searchResults = try await firestoreService.searchUsers(
                query: searchText,
                excludeUserId: userId
            )
        } catch {
            print("Search error: \(error)")
        }

        isSearching = false
    }

    private func sendRequest(to user: UserProfile) async {
        guard let userId = authService.user?.uid,
              let toUserId = user.id,
              let profile = try? await firestoreService.getUserProfile(userId: userId) else { return }

        do {
            try await firestoreService.sendFriendRequest(
                fromUserId: userId,
                fromDisplayName: profile.displayName,
                toUserId: toUserId
            )
            sentRequests.insert(toUserId)
        } catch {
            print("Send request error: \(error)")
        }
    }
}

struct UserSearchRow: View {
    let user: UserProfile
    let isFriend: Bool
    let requestSent: Bool
    let onSendRequest: () async -> Void

    @State private var isSending = false

    var body: some View {
        HStack {
            Text(user.displayName)
                .font(.headline)

            Spacer()

            if isFriend {
                Text("フレンド")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if requestSent || isSending {
                Text("送信済み")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    isSending = true
                    Task {
                        await onSendRequest()
                        isSending = false
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    UserSearchView()
        .environmentObject(AuthenticationService())
}
