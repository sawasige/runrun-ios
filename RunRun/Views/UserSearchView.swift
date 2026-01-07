import SwiftUI
import FirebaseAuth

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var sentRequests: Set<String> = []
    @State private var existingFriends: Set<String> = []

    private let firestoreService = FirestoreService.shared

    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No users found")
                        .foregroundStyle(.secondary)
                }
                ForEach(searchResults) { user in
                    UserSearchRow(
                        user: user,
                        isFriend: existingFriends.contains(user.id ?? ""),
                        requestSent: sentRequests.contains(user.id ?? ""),
                        onSendRequest: { await sendRequest(to: user) }
                    )
                }
            }
            .navigationTitle("Search Users")
            .navigationBarTitleDisplayMode(.inline)
            .analyticsScreen("UserSearch")
            .searchable(text: $searchText, prompt: "Search by display name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task(id: searchText) {
                guard !searchText.isEmpty else {
                    searchResults = []
                    return
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await performSearch(query: searchText)
            }
            .task {
                // バックグラウンドで実行してUIをブロックしない
                await Task.detached {
                    let userId = await MainActor.run { authService.user?.uid }
                    guard let userId else { return }
                    do {
                        let friendIds = try await firestoreService.getFriends(userId: userId)
                        await MainActor.run {
                            existingFriends = Set(friendIds)
                        }
                    } catch {
                        print("Load friends error: \(error)")
                    }
                }.value
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else { return }
        guard let userId = authService.user?.uid else { return }

        do {
            let results = try await firestoreService.searchUsers(
                query: query,
                excludeUserId: userId
            )
            guard !Task.isCancelled else { return }
            searchResults = results
        } catch {
            print("Search error: \(error)")
        }
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
            AnalyticsService.logEvent("send_friend_request")
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
                Text("Friend")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if requestSent || isSending {
                Text("Sent")
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
