import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var showNavBarLogo = false
    @State private var monthlyDistance: Double = 0
    @State private var monthlyRunCount: Int = 0
    @State private var displayName: String = ""
    @State private var userProfile: UserProfile?

    private let firestoreService = FirestoreService.shared

    private var currentMonthLabel: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: now)
    }

    init(userId: String) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.runs.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.runs.isEmpty {
                    errorView(error: error)
                } else if viewModel.runs.isEmpty {
                    emptyView
                } else {
                    timelineList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                        Text("RunRun")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .opacity(showNavBarLogo ? 1 : 0)
                }
            }
            .refreshable {
                await viewModel.refresh()
                await loadMonthlySummary()
            }
            .task {
                await viewModel.onAppear()
                await loadMonthlySummary()
            }
        }
    }

    private var expandedHeaderView: some View {
        VStack(spacing: 16) {
            // 上部: ロゴとユーザー情報
            HStack(spacing: 12) {
                // 左: ロゴとタイトル
                VStack(spacing: 4) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 36)

                    Text("RunRun")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                Spacer()

                // 右: アバターと表示名
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(currentMonthLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let profile = userProfile {
                        ProfileAvatarView(user: profile, size: 44)
                    } else {
                        ProfileAvatarView(iconName: "figure.run", avatarURL: nil, size: 44)
                    }
                }
            }

            // 下部: 今月のサマリ
            HStack(spacing: 0) {
                // 距離
                VStack(spacing: 4) {
                    Text("距離")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", monthlyDistance))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // 回数
                VStack(spacing: 4) {
                    Text("回数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(monthlyRunCount)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                        let threshold: CGFloat = 100
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNavBarLogo = newValue < threshold
                        }
                    }
            }
        )
    }

    private func loadMonthlySummary() async {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            async let runsTask = firestoreService.getUserMonthlyRuns(
                userId: viewModel.userId,
                year: year,
                month: month
            )
            async let profileTask = firestoreService.getUserProfile(userId: viewModel.userId)

            let runs = try await runsTask
            let profile = try await profileTask

            monthlyDistance = runs.reduce(0) { $0 + $1.distanceInKilometers }
            monthlyRunCount = runs.count
            displayName = profile?.displayName ?? ""
            userProfile = profile
        } catch {
            print("Failed to load monthly summary: \(error)")
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .foregroundStyle(.secondary)
                .padding(.top)
            Spacer()
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "まだ記録がありません",
            systemImage: "figure.run",
            description: Text("あなたとフレンドのランニング記録がここに表示されます")
        )
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button("再読み込み") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                expandedHeaderView

                ForEach(viewModel.dayGroups) { group in
                    sectionHeader(title: group.formattedDate)

                    ForEach(group.runs) { run in
                        NavigationLink {
                            let isOwn = run.userId == viewModel.userId
                            RunDetailView(
                                record: run.toRunningRecord(),
                                isOwnRecord: isOwn,
                                userProfile: isOwn ? nil : run.toUserProfile()
                            )
                        } label: {
                            TimelineRunRow(run: run)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.hasMore {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

private struct TimelineRunRow: View {
    let run: TimelineRun

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(iconName: run.iconName, avatarURL: run.avatarURL, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(run.displayName)
                        .font(.headline)
                    Spacer()
                    Text(run.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    Label(run.formattedDistance, systemImage: "ruler")
                    Label(run.formattedDuration, systemImage: "clock")
                    Label(run.formattedPace, systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

#Preview {
    TimelineView(userId: "preview")
}
