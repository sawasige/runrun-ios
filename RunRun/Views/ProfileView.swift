import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthenticationService
    let user: UserProfile

    @State private var isFriend = false
    @State private var isLoading = true
    @State private var totalDistance: Double = 0
    @State private var totalRuns: Int = 0
    @State private var isProcessing = false
    @State private var canSendRequest = true
    @State private var lastRequestDate: Date?

    private let firestoreService = FirestoreService()

    private var isCurrentUser: Bool {
        user.id == authService.user?.uid
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ProfileAvatarView(user: user, size: 100)

                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("統計") {
                HStack {
                    Label("総距離", systemImage: "figure.run")
                    Spacer()
                    Text(String(format: "%.1f km", totalDistance))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("ラン回数", systemImage: "number")
                    Spacer()
                    Text("\(totalRuns)回")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    MonthlyRunningView(user: user)
                } label: {
                    Label("記録を見る", systemImage: "chart.bar")
                }
            }

            if !isCurrentUser {
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if isFriend {
                        Button(role: .destructive) {
                            Task { await removeFriend() }
                        } label: {
                            HStack {
                                Spacer()
                                if isProcessing {
                                    ProgressView()
                                } else {
                                    Label("フレンドを解除", systemImage: "person.badge.minus")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isProcessing)
                    } else if canSendRequest {
                        Button {
                            Task { await sendFriendRequest() }
                        } label: {
                            HStack {
                                Spacer()
                                if isProcessing {
                                    ProgressView()
                                } else {
                                    Label("フレンド申請を送る", systemImage: "person.badge.plus")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isProcessing)
                    } else {
                        VStack(spacing: 4) {
                            Text("申請済み")
                                .foregroundStyle(.secondary)
                            if let lastDate = lastRequestDate {
                                Text(remainingTimeText(from: lastDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        guard let currentUserId = authService.user?.uid,
              let userId = user.id else { return }

        isLoading = true

        do {
            // フレンド状態を確認
            if !isCurrentUser {
                isFriend = try await firestoreService.isFriend(
                    currentUserId: currentUserId,
                    otherUserId: userId
                )

                // フレンド申請可能かチェック
                if !isFriend {
                    canSendRequest = try await firestoreService.canSendFriendRequest(
                        fromUserId: currentUserId,
                        toUserId: userId
                    )
                    if !canSendRequest {
                        lastRequestDate = try await firestoreService.getLastFriendRequestDate(
                            fromUserId: currentUserId,
                            toUserId: userId
                        )
                    }
                }
            }

            // 統計を取得
            let runs = try await firestoreService.getUserRuns(userId: userId)
            totalDistance = runs.reduce(0) { $0 + $1.distanceKm }
            totalRuns = runs.count
        } catch {
            print("Load error: \(error)")
        }

        isLoading = false
    }

    private func remainingTimeText(from date: Date) -> String {
        let endDate = date.addingTimeInterval(24 * 60 * 60)
        let remaining = endDate.timeIntervalSince(Date())

        if remaining <= 0 {
            return "まもなく再申請可能"
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "あと\(hours)時間\(minutes)分で再申請可能"
        } else {
            return "あと\(minutes)分で再申請可能"
        }
    }

    private func sendFriendRequest() async {
        guard let currentUserId = authService.user?.uid,
              let toUserId = user.id else { return }

        isProcessing = true

        do {
            let profile = try await firestoreService.getUserProfile(userId: currentUserId)
            try await firestoreService.sendFriendRequest(
                fromUserId: currentUserId,
                fromDisplayName: profile?.displayName ?? "ユーザー",
                toUserId: toUserId
            )
            canSendRequest = false
            lastRequestDate = Date()
        } catch {
            print("Send request error: \(error)")
        }

        isProcessing = false
    }

    private func removeFriend() async {
        guard let currentUserId = authService.user?.uid,
              let friendUserId = user.id else { return }

        isProcessing = true

        do {
            try await firestoreService.removeFriend(
                currentUserId: currentUserId,
                friendUserId: friendUserId
            )
            isFriend = false
        } catch {
            print("Remove friend error: \(error)")
        }

        isProcessing = false
    }
}

#Preview {
    NavigationStack {
        ProfileView(user: UserProfile(
            id: "test",
            displayName: "テストユーザー",
            email: nil,
            iconName: "figure.run"
        ))
    }
    .environmentObject(AuthenticationService())
}
