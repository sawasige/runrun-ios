import SwiftUI
import FirebaseAuth

/// 目標一覧画面（設定画面からナビゲーション）
struct GoalListView: View {
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric
    @State private var monthlyGoals: [RunningGoal] = []
    @State private var yearlyGoals: [RunningGoal] = []
    @State private var isLoading = true
    @State private var showingGoalSettings = false
    @State private var editingGoalType: RunningGoal.GoalType = .monthly
    @State private var editingYear: Int = Calendar.current.component(.year, from: Date())
    @State private var editingMonth: Int? = Calendar.current.component(.month, from: Date())
    @State private var editingGoal: RunningGoal?
    @State private var defaultMonthlyDistance: Double?
    @State private var defaultYearlyDistance: Double?

    private let firestoreService = FirestoreService.shared

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var body: some View {
        List {
            Section {
                Text("Set monthly or yearly distance goals to track your progress.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Current Month") {
                if isLoading {
                    ProgressView()
                } else {
                    let currentMonthGoal = monthlyGoals.first { $0.year == currentYear && $0.month == currentMonth }
                    if let goal = currentMonthGoal {
                        GoalRow(goal: goal, useMetric: useMetric) {
                            editGoal(goal)
                        }
                    } else {
                        Button {
                            createMonthlyGoal(year: currentYear, month: currentMonth)
                        } label: {
                            Label("Set Goal", systemImage: "plus.circle")
                        }
                    }
                }
            }

            Section("Current Year") {
                if isLoading {
                    ProgressView()
                } else {
                    let currentYearGoal = yearlyGoals.first { $0.year == currentYear }
                    if let goal = currentYearGoal {
                        GoalRow(goal: goal, useMetric: useMetric) {
                            editGoal(goal)
                        }
                    } else {
                        Button {
                            createYearlyGoal(year: currentYear)
                        } label: {
                            Label("Set Goal", systemImage: "plus.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .analyticsScreen("Goals")
        .task {
            await loadGoals()
        }
        .refreshable {
            await loadGoals()
        }
        .sheet(isPresented: $showingGoalSettings) {
            GoalSettingsView(
                goalType: editingGoalType,
                year: editingYear,
                month: editingMonth,
                currentGoal: editingGoal,
                defaultDistanceKm: editingGoalType == .monthly ? defaultMonthlyDistance : defaultYearlyDistance,
                onSave: { goal in
                    Task { await saveGoal(goal) }
                },
                onDelete: editingGoal != nil ? {
                    Task { await deleteGoal(editingGoal!) }
                } : nil
            )
        }
    }

    private func loadGoals() async {
        guard let userId = userId else { return }

        isLoading = true

        do {
            // 現在の月間・年間目標を取得
            async let monthlyGoalTask = firestoreService.getMonthlyGoal(userId: userId, year: currentYear, month: currentMonth)
            async let yearlyGoalTask = firestoreService.getYearlyGoal(userId: userId, year: currentYear)
            async let defaultMonthlyTask = firestoreService.getLatestMonthlyGoal(userId: userId)
            async let defaultYearlyTask = firestoreService.getLatestYearlyGoal(userId: userId)

            let monthlyGoal = try await monthlyGoalTask
            let yearlyGoal = try await yearlyGoalTask
            let latestMonthly = try await defaultMonthlyTask
            let latestYearly = try await defaultYearlyTask

            monthlyGoals = monthlyGoal.map { [$0] } ?? []
            yearlyGoals = yearlyGoal.map { [$0] } ?? []
            defaultMonthlyDistance = latestMonthly?.targetDistanceKm
            defaultYearlyDistance = latestYearly?.targetDistanceKm
        } catch {
            print("Failed to load goals: \(error)")
        }

        isLoading = false
    }

    private func createMonthlyGoal(year: Int, month: Int) {
        editingGoalType = .monthly
        editingYear = year
        editingMonth = month
        editingGoal = nil
        showingGoalSettings = true
    }

    private func createYearlyGoal(year: Int) {
        editingGoalType = .yearly
        editingYear = year
        editingMonth = nil
        editingGoal = nil
        showingGoalSettings = true
    }

    private func editGoal(_ goal: RunningGoal) {
        editingGoalType = goal.type
        editingYear = goal.year
        editingMonth = goal.month
        editingGoal = goal
        showingGoalSettings = true
    }

    private func saveGoal(_ goal: RunningGoal) async {
        guard let userId = userId else { return }

        do {
            try await firestoreService.setGoal(userId: userId, goal: goal)
            AnalyticsService.logEvent("set_goal", parameters: [
                "type": goal.type.rawValue,
                "target_km": goal.targetDistanceKm
            ])
            await loadGoals()
        } catch {
            print("Failed to save goal: \(error)")
        }
    }

    private func deleteGoal(_ goal: RunningGoal) async {
        guard let userId = userId, let goalId = goal.id else { return }

        do {
            try await firestoreService.deleteGoal(userId: userId, goalId: goalId)
            AnalyticsService.logEvent("delete_goal", parameters: [
                "type": goal.type.rawValue
            ])
            await loadGoals()
        } catch {
            print("Failed to delete goal: \(error)")
        }
    }
}

/// 目標行
private struct GoalRow: View {
    let goal: RunningGoal
    let useMetric: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(goal.formattedTargetDistance(useMetric: useMetric))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var periodLabel: String {
        switch goal.type {
        case .monthly:
            guard let month = goal.month else { return "" }
            var components = DateComponents()
            components.year = goal.year
            components.month = month
            components.day = 1
            guard let date = Calendar.current.date(from: components) else {
                return "\(goal.year)/\(month)"
            }
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: date)
        case .yearly:
            return MonthlyRunningStats.formattedYear(goal.year)
        }
    }
}

#Preview {
    NavigationStack {
        GoalListView()
    }
}
