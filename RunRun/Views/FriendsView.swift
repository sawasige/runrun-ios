import SwiftUI
import FirebaseAuth

struct FriendsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var badgeService: BadgeService
    @State private var friends: [UserProfile] = []
    @State private var friendRequests: [FriendRequest] = []
    @State private var isLoading = true

    // 検索モード
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var sentRequests: Set<String> = []
    @State private var isSearchInProgress = false

    private let firestoreService = FirestoreService.shared

    var body: some View {
        Group {
            if isLoading && friends.isEmpty && friendRequests.isEmpty && !isSearching {
                FriendsSkeletonView()
            } else {
                List {
                    if isSearching {
                        // 検索結果
                        if searchText.isEmpty {
                            // 検索文字を入力していない場合は何も表示しない
                        } else if isSearchInProgress {
                            // 検索中
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if searchResults.isEmpty {
                            // 検索完了だが結果なし
                            ContentUnavailableView(
                                String(localized: "No Users Found"),
                                systemImage: "magnifyingglass",
                                description: Text("Try a different search term")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            // 検索結果あり
                            ForEach(searchResults) { user in
                                NavigationLink(value: ScreenType.profile(user)) {
                                    UserSearchRow(
                                        user: user,
                                        isFriend: friends.contains { $0.id == user.id },
                                        requestSent: sentRequests.contains(user.id ?? ""),
                                        onSendRequest: { await sendRequest(to: user) }
                                    )
                                }
                            }
                        }
                    } else {
                        // フレンド一覧
                        if !friendRequests.isEmpty {
                            Section("Requests") {
                                ForEach(friendRequests) { request in
                                    FriendRequestRow(
                                        request: request,
                                        onAccept: { await acceptRequest(request) },
                                        onReject: { await rejectRequest(request) }
                                    )
                                }
                            }
                        }

                        Section("Friends (\(friends.count))") {
                            if friends.isEmpty {
                                Text("No friends yet")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(friends) { friend in
                                    NavigationLink(value: ScreenType.profile(friend)) {
                                        FriendRow(friend: friend)
                                    }
                                }
                                .onDelete(perform: deleteFriend)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $searchText, isPresented: $isSearching, prompt: Text("Search users"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSearching = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .task(id: searchText) {
            guard isSearching, !searchText.isEmpty else {
                searchResults = []
                isSearchInProgress = false
                return
            }
            isSearchInProgress = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query: searchText)
            isSearchInProgress = false
        }
        .onChange(of: isSearching) { _, newValue in
            if !newValue {
                searchText = ""
                searchResults = []
            }
        }
        .onAppear {
            AnalyticsService.logScreenView("Friends")
        }
    }

    private func loadData() async {
        guard let userId = authService.user?.uid else { return }

        // データがない場合のみローディング表示（チラつき防止）
        if friends.isEmpty {
            isLoading = true
        }

        // デバッグ用遅延
        await DebugSettings.applyLoadDelay()

        do {
            async let friendsTask = firestoreService.getFriendProfiles(userId: userId)
            async let requestsTask = firestoreService.getFriendRequests(userId: userId)

            friends = try await friendsTask
            friendRequests = try await requestsTask

            // バッジをクリア
            badgeService.markRequestsAsSeen(userId: userId)
            badgeService.markFriendsAsSeen(userId: userId)
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
            AnalyticsService.logEvent("accept_friend_request")
            await loadData()
        } catch {
            print("Accept error: \(error)")
        }
    }

    private func rejectRequest(_ request: FriendRequest) async {
        guard let requestId = request.id else { return }

        do {
            try await firestoreService.rejectFriendRequest(requestId: requestId)
            AnalyticsService.logEvent("reject_friend_request")
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
                AnalyticsService.logEvent("remove_friend")
                await loadData()
            }
        }
    }

    // MARK: - Search

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
                Text("Friend Request")
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
        HStack(spacing: 12) {
            ProfileAvatarView(user: friend, size: 36)

            Text(friend.displayName)
                .font(.headline)
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthenticationService())
}
