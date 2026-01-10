import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @EnvironmentObject private var syncService: SyncService
    @State private var showNavBarLogo = false
    @State private var monthlyDistance: Double = 0
    @State private var monthlyRunCount: Int = 0
    @State private var displayName: String = ""
    @State private var userProfile: UserProfile?

    private let firestoreService = FirestoreService.shared

    private var currentMonthLabel: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
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
                    .blur(radius: showNavBarLogo ? 0 : 8)
                    .offset(y: showNavBarLogo ? 0 : 16)
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
            .onAppear {
                AnalyticsService.logScreenView("Timeline")
            }
            .onChange(of: syncService.lastSyncedAt) { _, _ in
                Task {
                    await viewModel.refresh()
                    await loadMonthlySummary()
                }
            }
        }
    }

    private var expandedHeaderView: some View {
        VStack(spacing: 16) {
            // 上部中央: ロゴとタイトル（横並び）
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)

                Text("RunRun")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // 今月のサマリ（タップで詳細へ）
            NavigationLink {
                MonthDetailView(
                    userId: viewModel.userId,
                    year: Calendar.current.component(.year, from: Date()),
                    month: Calendar.current.component(.month, from: Date())
                )
            } label: {
                HStack(spacing: 0) {
                    // 左: プロフィール
                    if let profile = userProfile {
                        ProfileAvatarView(user: profile, size: 56)
                    } else {
                        ProfileAvatarView(iconName: "figure.run", avatarURL: nil, size: 56)
                    }

                    Divider()
                        .frame(height: 56)
                        .padding(.horizontal, 12)

                    // 右: 今月の記録
                    VStack(spacing: 6) {
                        Text(currentMonthLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        HStack(spacing: 0) {
                            // 距離
                            VStack(spacing: 2) {
                                Text("Distance")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", monthlyDistance))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                Text("km")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            // 回数
                            VStack(spacing: 2) {
                                Text("Runs")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(monthlyRunCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                Text("runs")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timeline_month_summary")
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                        let threshold: CGFloat = 100
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showNavBarLogo = newValue < threshold
                        }
                    }
            }
        )
    }

    private func loadMonthlySummary() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            monthlyDistance = 68.5
            monthlyRunCount = 12
            userProfile = MockDataProvider.currentUser
            displayName = MockDataProvider.currentUser.displayName
            return
        }

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
            Text("Loading...")
                .foregroundStyle(.secondary)
                .padding(.top)
            Spacer()
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No records yet",
            systemImage: "figure.run",
            description: Text("Your and your friends' running records will appear here")
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
            Button("Reload") {
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
