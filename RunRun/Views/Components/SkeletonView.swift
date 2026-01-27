import SwiftUI

// MARK: - Shimmer Animation

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.5)
                }
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Basic Skeleton Components

/// 基本のスケルトン矩形
struct SkeletonRect: View {
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.label).opacity(0.1))
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// 円形スケルトン（アバター用）
struct SkeletonCircle: View {
    var body: some View {
        Circle()
            .fill(Color(.label).opacity(0.1))
            .shimmer()
            .clipShape(Circle())
    }
}

// MARK: - Skeleton Rows

/// 月別統計行のスケルトン（YearDetailView用）
struct SkeletonMonthRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                SkeletonRect()
                    .frame(width: 80, height: 16)
                SkeletonRect()
                    .frame(width: 50, height: 12)
            }
            Spacer()
            SkeletonRect()
                .frame(width: 60, height: 20)
        }
        .padding(.vertical, 4)
    }
}

/// ラン記録行のスケルトン（MonthDetailView用）
struct SkeletonRunRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SkeletonRect()
                    .frame(width: 100, height: 14)
                Spacer()
                SkeletonRect()
                    .frame(width: 60, height: 16)
            }
            HStack(spacing: 16) {
                SkeletonRect()
                    .frame(width: 70, height: 12)
                SkeletonRect()
                    .frame(width: 70, height: 12)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 週別統計行のスケルトン（WeeklyStatsView用）
struct SkeletonWeeklyRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SkeletonRect()
                    .frame(width: 120, height: 14)
                Spacer()
                SkeletonRect()
                    .frame(width: 60, height: 16)
            }
            HStack(spacing: 16) {
                SkeletonRect()
                    .frame(width: 60, height: 12)
                SkeletonRect()
                    .frame(width: 80, height: 12)
            }
        }
        .padding(.vertical, 4)
    }
}

/// ランキング行のスケルトン（LeaderboardView用）
struct SkeletonLeaderboardRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle()
                .frame(width: 28, height: 28)
            SkeletonCircle()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                SkeletonRect()
                    .frame(width: 100, height: 16)
                SkeletonRect()
                    .frame(width: 50, height: 12)
            }
            Spacer()
            SkeletonRect()
                .frame(width: 60, height: 20)
        }
        .padding(.vertical, 4)
    }
}

/// フレンド行のスケルトン（FriendsView用）
struct SkeletonFriendRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle()
                .frame(width: 36, height: 36)
            SkeletonRect()
                .frame(width: 100, height: 16)
            Spacer()
        }
    }
}

/// タイムライン行のスケルトン（TimelineView用）
struct SkeletonTimelineRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                SkeletonRect()
                    .frame(width: 80, height: 14)
                SkeletonRect()
                    .frame(width: 100, height: 12)
            }
            Spacer()
            SkeletonRect()
                .frame(width: 60, height: 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

// MARK: - Skeleton Charts

/// シャインする背景（listRowBackgroundで使用）
struct ShimmerBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemGray5))
            .shimmer()
    }
}

/// チャートのスケルトン（透明、listRowBackgroundと併用）
struct SkeletonChart: View {
    var body: some View {
        Color.clear
    }
}

/// カレンダーのスケルトン（透明、listRowBackgroundと併用）
struct SkeletonCalendar: View {
    let year: Int
    let month: Int

    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 44

    private var calendar: Calendar { Calendar.current }

    private var firstDayOfMonth: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
    }

    private var firstWeekday: Int {
        calendar.component(.weekday, from: firstDayOfMonth) - 1
    }

    private var numberOfWeeks: Int {
        let totalCells = firstWeekday + daysInMonth
        return (totalCells + 6) / 7
    }

    private var calendarHeight: CGFloat {
        let headerHeight: CGFloat = 20
        let headerSpacing: CGFloat = 8
        let gridHeight = cellHeight * CGFloat(numberOfWeeks) + 4 * CGFloat(numberOfWeeks - 1)
        return headerHeight + headerSpacing + gridHeight
    }

    var body: some View {
        Color.clear
            .frame(height: calendarHeight)
    }
}

// MARK: - Full Screen Skeletons

/// YearDetailView用スケルトン
struct YearDetailSkeletonView: View {
    var body: some View {
        List {
            Section("Monthly Distance") {
                SkeletonChart()
                    .frame(height: 200)
            }

            Section("Distance Progress") {
                SkeletonChart()
                    .frame(height: 200)
            }

            Section("Totals") {
                ForEach(0..<4, id: \.self) { _ in
                    HStack {
                        SkeletonRect()
                            .frame(width: 80, height: 14)
                        Spacer()
                        SkeletonRect()
                            .frame(width: 60, height: 14)
                    }
                }
            }

            Section("Averages") {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        SkeletonRect()
                            .frame(width: 100, height: 14)
                        Spacer()
                        SkeletonRect()
                            .frame(width: 50, height: 14)
                    }
                }
            }

            Section("Monthly Records") {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonMonthRow()
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// MonthDetailView用スケルトン
struct MonthDetailSkeletonView: View {
    var body: some View {
        List {
            // 日付ヘッダー
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                SkeletonRect()
                    .frame(width: 60, height: 14)
                SkeletonRect()
                    .frame(width: 10, height: 10)
                SkeletonRect()
                    .frame(width: 100, height: 28)
                Spacer()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // カレンダー
            Section {
                SkeletonCalendar(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()))
            }

            // グラフ
            Section("Daily Distance") {
                SkeletonChart()
                    .frame(height: 150)
            }

            Section("Distance Progress") {
                SkeletonChart()
                    .frame(height: 150)
            }

            // 統計
            Section("Totals") {
                ForEach(0..<4, id: \.self) { _ in
                    HStack {
                        SkeletonRect()
                            .frame(width: 80, height: 14)
                        Spacer()
                        SkeletonRect()
                            .frame(width: 60, height: 14)
                    }
                }
            }

            // ラン記録
            Section("Running Records") {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRunRow()
                }
            }
        }
        .contentMargins(.top, 0)
    }
}

/// WeeklyStatsView用スケルトン
struct WeeklyStatsSkeletonView: View {
    var body: some View {
        List {
            Section {
                SkeletonChart()
                    .frame(height: 200)
                    .listRowBackground(ShimmerBackground())
            }

            Section("Weekly Data") {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonWeeklyRow()
                }
            }
        }
    }
}

/// LeaderboardView用スケルトン
struct LeaderboardSkeletonView: View {
    let filterSection: AnyView

    var body: some View {
        List {
            Section {
                filterSection
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(0..<10, id: \.self) { _ in
                    SkeletonLeaderboardRow()
                }
            }
        }
    }
}

/// FriendsView用スケルトン
struct FriendsSkeletonView: View {
    var body: some View {
        List {
            Section("Friends") {
                SkeletonFriendRow()
            }
        }
    }
}

/// TimelineView用スケルトン
struct TimelineSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ヘッダー部分
                VStack(spacing: 16) {
                    // ロゴ
                    HStack(spacing: 8) {
                        SkeletonRect(cornerRadius: 8)
                            .frame(width: 44, height: 44)
                        SkeletonRect()
                            .frame(width: 80, height: 20)
                    }

                    // 月サマリカード
                    VStack(spacing: 8) {
                        HStack {
                            SkeletonRect()
                                .frame(width: 100, height: 14)
                            Spacer()
                            SkeletonRect()
                                .frame(width: 10, height: 10)
                        }

                        // ミニカレンダー
                        SkeletonCalendar(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()))
                            .frame(height: 120)

                        Divider()

                        // 統計
                        HStack {
                            VStack(spacing: 2) {
                                SkeletonRect()
                                    .frame(width: 50, height: 10)
                                SkeletonRect()
                                    .frame(width: 60, height: 20)
                            }
                            Spacer()
                            Divider()
                                .frame(height: 30)
                            Spacer()
                            VStack(spacing: 2) {
                                SkeletonRect()
                                    .frame(width: 40, height: 10)
                                SkeletonRect()
                                    .frame(width: 40, height: 20)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.vertical, 16)

                // タイムライン行
                ForEach(0..<3, id: \.self) { groupIndex in
                    // セクションヘッダー
                    HStack {
                        SkeletonRect()
                            .frame(width: 80, height: 14)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)

                    // ラン行
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonTimelineRow()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Previews

#Preview("Skeleton Rows") {
    List {
        Section("Month Row") {
            SkeletonMonthRow()
        }
        Section("Run Row") {
            SkeletonRunRow()
        }
        Section("Weekly Row") {
            SkeletonWeeklyRow()
        }
        Section("Leaderboard Row") {
            SkeletonLeaderboardRow()
        }
        Section("Friend Row") {
            SkeletonFriendRow()
        }
        Section("Timeline Row") {
            SkeletonTimelineRow()
        }
    }
}

#Preview("Year Detail Skeleton") {
    NavigationStack {
        YearDetailSkeletonView()
            .navigationTitle("2025 Records")
    }
}

#Preview("Month Detail Skeleton") {
    NavigationStack {
        MonthDetailSkeletonView()
            .navigationTitle("January 2025")
    }
}

#Preview("Weekly Stats Skeleton") {
    NavigationStack {
        WeeklyStatsSkeletonView()
            .navigationTitle("Weekly Trends")
    }
}

#Preview("Leaderboard Skeleton") {
    NavigationStack {
        LeaderboardSkeletonView(filterSection: AnyView(Text("Filter")))
            .navigationTitle("Leaderboard")
    }
}

#Preview("Friends Skeleton") {
    NavigationStack {
        FriendsSkeletonView()
            .navigationTitle("Friends")
    }
}

#Preview("Timeline Skeleton") {
    NavigationStack {
        TimelineSkeletonView()
    }
}
