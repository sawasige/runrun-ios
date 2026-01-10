import SwiftUI
import Charts

struct MonthDetailView: View {
    @StateObject private var viewModel: MonthDetailViewModel
    @EnvironmentObject private var syncService: SyncService
    let userProfile: UserProfile?
    let userId: String
    @State private var selectedCalendarRecord: RunningRecord?
    @State private var currentYear: Int
    @State private var currentMonth: Int
    @State private var hasLoadedOnce = false

    init(userId: String, year: Int, month: Int) {
        self.userProfile = nil
        self.userId = userId
        _currentYear = State(initialValue: year)
        _currentMonth = State(initialValue: month)
        _viewModel = StateObject(wrappedValue: MonthDetailViewModel(userId: userId, year: year, month: month))
    }

    init(user: UserProfile, year: Int, month: Int) {
        self.userProfile = user
        self.userId = user.id ?? ""
        _currentYear = State(initialValue: year)
        _currentMonth = State(initialValue: month)
        _viewModel = StateObject(wrappedValue: MonthDetailViewModel(userId: user.id ?? "", year: year, month: month))
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        let calendar = Calendar.current
        return currentYear == calendar.component(.year, from: now) &&
               currentMonth == calendar.component(.month, from: now)
    }

    private func dayString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: String(localized: "%d day_suffix", comment: "Day format e.g. 15日"), day)
    }

    private func goToPreviousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }

    private func goToNextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }

    private var monthNavigationButtons: some View {
        HStack(spacing: 0) {
            Button {
                goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }

            Divider()
                .frame(height: 30)

            Button {
                goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 50)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading && !hasLoadedOnce {
                    ProgressView()
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else if viewModel.records.isEmpty {
                    emptyView
                } else {
                    recordsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // フローティング月切り替えボタン
            monthNavigationButtons
                .padding()
                .padding(.bottom, 8)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .analyticsScreen("MonthDetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let user = userProfile {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        ProfileAvatarView(user: user, size: 28)
                    }
                }
            }
        }
        .task {
            await viewModel.onAppear()
            hasLoadedOnce = true
        }
        .onChange(of: currentYear) { _, _ in
            Task {
                await viewModel.updateMonth(year: currentYear, month: currentMonth)
            }
        }
        .onChange(of: currentMonth) { _, _ in
            Task {
                await viewModel.updateMonth(year: currentYear, month: currentMonth)
            }
        }
        .onChange(of: syncService.lastSyncedAt) { _, _ in
            // 自分のデータの場合のみリロード
            if userProfile == nil {
                Task {
                    await viewModel.updateMonth(year: currentYear, month: currentMonth)
                }
            }
        }
    }

    private var recordsList: some View {
        List {
            // カレンダー
            Section {
                RunCalendarView(
                    year: viewModel.year,
                    month: viewModel.month,
                    records: viewModel.records,
                    selectedRecord: $selectedCalendarRecord
                )
            }

            // 日別グラフ
            Section("Daily Distance") {
                dailyChart
                    .frame(height: 150)
            }

            Section("Totals") {
                LabeledContent("Distance") {
                    Text(viewModel.formattedTotalDistance)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                LabeledContent("Time", value: viewModel.formattedTotalDuration)
                LabeledContent("Count", value: String(format: String(localized: "%d runs", comment: "Run count"), viewModel.runCount))
                if userProfile == nil, let calories = viewModel.formattedTotalCalories {
                    LabeledContent("Energy", value: calories)
                }
            }

            Section("Averages") {
                LabeledContent("Pace", value: viewModel.formattedAveragePace)
                LabeledContent("Distance/Run", value: viewModel.formattedAverageDistance)
                LabeledContent("Time/Run", value: viewModel.formattedAverageDuration)
            }

            if viewModel.bestDayByDistance != nil || viewModel.bestDayByDuration != nil || viewModel.fastestDay != nil {
                Section("Highlights") {
                    if let best = viewModel.bestDayByDistance {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Best Distance Day", value: "\(dayString(from: best.date)) (\(best.formattedDistance))")
                        }
                    }
                    if let best = viewModel.bestDayByDuration {
                        NavigationLink {
                            RunDetailView(
                                record: best,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Best Duration Day", value: "\(dayString(from: best.date)) (\(best.formattedDuration))")
                        }
                    }
                    if let fastest = viewModel.fastestDay {
                        NavigationLink {
                            RunDetailView(
                                record: fastest,
                                isOwnRecord: userProfile == nil,
                                userProfile: userProfile,
                                userId: viewModel.userId
                            )
                        } label: {
                            LabeledContent("Fastest Day", value: "\(dayString(from: fastest.date)) (\(fastest.formattedPace))")
                        }
                    }
                }
            }

            Section("Running Records") {
                ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                    NavigationLink {
                        RunDetailView(
                            record: record,
                            isOwnRecord: userProfile == nil,
                            userProfile: userProfile,
                            userId: viewModel.userId
                        )
                    } label: {
                        RunningRecordRow(record: record)
                    }
                    .accessibilityIdentifier(index == 0 ? "first_run_row" : "run_row_\(index)")
                }
            }

            // フローティングボタン分の余白
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationDestination(item: $selectedCalendarRecord) { record in
            RunDetailView(
                record: record,
                isOwnRecord: userProfile == nil,
                userProfile: userProfile,
                userId: viewModel.userId
            )
        }
    }

    private var dailyChart: some View {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: viewModel.year, month: viewModel.month, day: 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return Chart(viewModel.records) { record in
            BarMark(
                x: .value(String(localized: "Day"), record.date, unit: .day),
                y: .value(String(localized: "Distance"), record.distanceInKilometers)
            )
            .foregroundStyle(Color.accentColor.gradient)

            if let best = viewModel.bestDayByDistance, calendar.isDate(record.date, inSameDayAs: best.date), best.distanceInKilometers > 0 {
                RuleMark(y: .value(String(localized: "Best"), best.distanceInKilometers))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartXScale(domain: startOfMonth...endOfMonth)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxisLabel("km")
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No running records for this month")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct RunningRecordRow: View {
    let record: RunningRecord

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MdEEE")
        return formatter.string(from: record.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.formattedDistance)
                    .font(.headline)
            }

            HStack(spacing: 16) {
                Label(record.formattedDuration, systemImage: "clock")
                Label(record.formattedPace, systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MonthDetailView(userId: "preview", year: 2025, month: 1)
    }
}
