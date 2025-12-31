import SwiftUI
import FirebaseAuth

enum LeaderboardFilter: String, CaseIterable {
    case all = "全員"
    case friends = "フレンド"
}

struct LeaderboardView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selectedFilter: LeaderboardFilter = .all

    private let firestoreService = FirestoreService()
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
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: Date())
        if year == currentYear {
            return "\(month)月"
        } else {
            return "\(year)年\(month)月"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Picker("フィルター", selection: $selectedFilter) {
                        ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("月", selection: $selectedDate) {
                        ForEach(availableMonths, id: \.self) { date in
                            Text(monthLabel(for: date)).tag(date)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if let error = errorMessage {
                        ContentUnavailableView(
                            "読み込みエラー",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    } else if users.isEmpty {
                        ContentUnavailableView(
                            "ランキングなし",
                            systemImage: "trophy",
                            description: Text("この月のデータがありません")
                        )
                    } else {
                        List {
                            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                NavigationLink {
                                    UserDetailView(
                                        user: user,
                                        year: selectedYear,
                                        month: selectedMonth
                                    )
                                } label: {
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
            .navigationTitle("ランキング")
            .refreshable {
                await loadLeaderboard()
            }
            .task {
                await loadLeaderboard()
            }
            .onChange(of: selectedDate) {
                Task { await loadLeaderboard() }
            }
            .onChange(of: selectedFilter) {
                Task { await loadLeaderboard() }
            }
        }
    }

    private func loadLeaderboard() async {
        guard let userId = authService.user?.uid else { return }

        isLoading = true
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

    var body: some View {
        HStack(spacing: 16) {
            rankBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? .blue : .primary)

                Text("\(user.totalRuns)回のラン")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(String(format: "%.1f km", user.totalDistanceKm))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrentUser ? Color.blue.opacity(0.1) : nil)
    }

    @ViewBuilder
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor)
                .frame(width: 36, height: 36)

            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue.opacity(0.6)
        }
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(AuthenticationService())
}
