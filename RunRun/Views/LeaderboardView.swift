import SwiftUI
import FirebaseAuth

enum LeaderboardFilter: CaseIterable {
    case all
    case friends

    var localizedName: String {
        switch self {
        case .all: return String(localized: "All")
        case .friends: return String(localized: "Friends")
        }
    }
}

struct LeaderboardView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var syncService: SyncService
    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selectedFilter: LeaderboardFilter = .all

    private let firestoreService = FirestoreService.shared
    private let calendar = Calendar.current

    private var availableMonths: [Date] {
        var months: [Date] = []
        let now = Date()
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                months.append(calendar.date(from: calendar.dateComponents([.year, .month], from: date))!)
            }
        }
        return months
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    filterSection
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack {
                    filterSection
                    ContentUnavailableView(
                        "Loading Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            } else if users.isEmpty {
                VStack {
                    filterSection
                    ContentUnavailableView(
                        "No Rankings",
                        systemImage: "trophy",
                        description: Text("No data for this month")
                    )
                }
            } else {
                List {
                    Section {
                        filterSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                            NavigationLink(value: ScreenType.profile(user)) {
                                LeaderboardRow(
                                    rank: index + 1,
                                    user: user,
                                    isCurrentUser: user.id == authService.user?.uid
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Leaderboard")
        .refreshable {
            await loadLeaderboard()
        }
        .task {
            await loadLeaderboard()
        }
        .onAppear {
            AnalyticsService.logScreenView("Leaderboard")
        }
        .onChange(of: selectedDate) {
            Task { await loadLeaderboard() }
        }
        .onChange(of: selectedFilter) {
            Task { await loadLeaderboard() }
        }
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            Task { await loadLeaderboard() }
        }
    }

    private var filterSection: some View {
        VStack(spacing: 8) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                    Text(filter.localizedName).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Month", selection: $selectedDate) {
                ForEach(availableMonths, id: \.self) { date in
                    Text(monthLabel(for: date)).tag(date)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }

    private func loadLeaderboard() async {
        // スクリーンショットモードではモックデータを使用
        if ScreenshotMode.isEnabled {
            users = MockDataProvider.leaderboardUsers
            isLoading = false
            return
        }

        guard let userId = authService.user?.uid else { return }

        // データがない場合のみローディング表示（チラつき防止）
        if users.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            switch selectedFilter {
            case .all:
                users = try await firestoreService.getMonthlyLeaderboard(year: selectedYear, month: selectedMonth)
            case .friends:
                users = try await firestoreService.getFriendsMonthlyLeaderboard(userId: userId, year: selectedYear, month: selectedMonth)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let user: UserProfile
    let isCurrentUser: Bool
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric

    var body: some View {
        HStack(spacing: 12) {
            rankBadge

            ProfileAvatarView(user: user, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? Color.accentColor : .primary)

                Text(String(format: String(localized: "%d runs", comment: "Run count"), user.totalRuns))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(UnitFormatter.formatDistance(user.totalDistanceKm, useMetric: useMetric, decimals: 1))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrentUser ? Color.accentColor.opacity(0.1) : nil)
    }

    @ViewBuilder
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor)
                .frame(width: 28, height: 28)

            Text("\(rank)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return Color.accentColor.opacity(0.6)
        }
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(AuthenticationService())
}
