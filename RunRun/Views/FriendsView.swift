import SwiftUI
import FirebaseAuth

struct FriendsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var friends: [UserProfile] = []
    @State private var friendRequests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var showingSearch = false

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        if !friendRequests.isEmpty {
                            Section("リクエスト") {
                                ForEach(friendRequests) { request in
                                    FriendRequestRow(
                                        request: request,
                                        onAccept: { await acceptRequest(request) },
                                        onReject: { await rejectRequest(request) }
                                    )
                                }
                            }
                        }

                        Section("フレンド (\(friends.count)人)") {
                            if friends.isEmpty {
                                Text("フレンドがいません")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(friends) { friend in
                                    FriendRow(friend: friend)
                                }
                                .onDelete(perform: deleteFriend)
                            }
                        }
                    }
                }
            }
            .navigationTitle("フレンド")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                UserSearchView()
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let userId = authService.user?.uid else { return }
        isLoading = true

        do {
            async let friendsTask = firestoreService.getFriendProfiles(userId: userId)
            async let requestsTask = firestoreService.getFriendRequests(userId: userId)

            friends = try await friendsTask
            friendRequests = try await requestsTask
        } catch {
            print("Load error: \(error)")
        }

        isLoading = false
    }

    private func acceptRequest(_ request: FriendRequest) async {
        guard let requestId = request.id,
              let userId = authService.user?.uid else { return }

        do {
            try await firestoreService.acceptFriendRequest(
                requestId: requestId,
                currentUserId: userId,
                friendUserId: request.fromUserId
            )
            await loadData()
        } catch {
            print("Accept error: \(error)")
        }
    }

    private func rejectRequest(_ request: FriendRequest) async {
        guard let requestId = request.id else { return }

        do {
            try await firestoreService.rejectFriendRequest(requestId: requestId)
            await loadData()
        } catch {
            print("Reject error: \(error)")
        }
    }

    private func deleteFriend(at offsets: IndexSet) {
        guard let userId = authService.user?.uid else { return }

        for index in offsets {
            let friend = friends[index]
            guard let friendId = friend.id else { continue }

            Task {
                try? await firestoreService.removeFriend(currentUserId: userId, friendUserId: friendId)
                await loadData()
            }
        }
    }
}

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(request.fromDisplayName)
                    .font(.headline)
                Text("フレンドリクエスト")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 12) {
                    Button {
                        isProcessing = true
                        Task {
                            await onAccept()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isProcessing = true
                        Task {
                            await onReject()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FriendRow: View {
    let friend: UserProfile

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(friend.displayName)
                    .font(.headline)
                Text("\(friend.totalRuns)回のラン")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f km", friend.totalDistanceKm))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthenticationService())
}
