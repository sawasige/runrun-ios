import SwiftUI

/// 目標設定画面
struct GoalSettingsView: View {
    let goalType: RunningGoal.GoalType
    let year: Int
    let month: Int?
    let currentGoal: RunningGoal?
    let userId: String
    let onSave: (RunningGoal) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("units.distance") private var useMetric = UnitFormatter.defaultUseMetric

    @State private var targetDistanceValue: Double?
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = true

    private let firestoreService = FirestoreService.shared

    init(
        goalType: RunningGoal.GoalType,
        year: Int,
        month: Int? = nil,
        currentGoal: RunningGoal? = nil,
        userId: String,
        onSave: @escaping (RunningGoal) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.goalType = goalType
        self.year = year
        self.month = month
        self.currentGoal = currentGoal
        self.userId = userId
        self.onSave = onSave
        self.onDelete = onDelete

        // 編集時は現在の目標値を使用、新規作成時はonAppearでフェッチ
        if let currentGoal = currentGoal {
            _targetDistanceValue = State(initialValue: UnitFormatter.convertDistance(currentGoal.targetDistanceKm, useMetric: UnitFormatter.defaultUseMetric))
            _isLoading = State(initialValue: false)
        }
    }

    private var title: String {
        switch goalType {
        case .monthly:
            return String(localized: "Monthly Goal")
        case .yearly:
            return String(localized: "Yearly Goal")
        }
    }

    private var periodDescription: String {
        switch goalType {
        case .monthly:
            guard let month = month else { return "" }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            guard let date = Calendar.current.date(from: components) else {
                return "\(year)/\(month)"
            }
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: date)
        case .yearly:
            return MonthlyRunningStats.formattedYear(year)
        }
    }

    /// 入力値をkmに変換
    private var targetDistanceKm: Double {
        let value = targetDistanceValue ?? 100
        if useMetric {
            return value
        } else {
            return value * UnitFormatter.milesToKm
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Period", comment: "Goal period label")
                        Spacer()
                        Text(periodDescription)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Target Distance", comment: "Goal target distance label")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            TextField("", value: Binding(
                                get: { targetDistanceValue ?? 100 },
                                set: { targetDistanceValue = $0 }
                            ), format: .number.precision(.fractionLength(1)).grouping(.never))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(UnitFormatter.distanceUnit(useMetric: useMetric))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !isLoading {
                        Stepper(value: Binding(
                            get: { targetDistanceValue ?? 100 },
                            set: { targetDistanceValue = $0 }
                        ), in: 1...10000, step: useMetric ? 10 : 5) {
                            EmptyView()
                        }
                    }
                }

                if currentGoal != nil && onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Goal", comment: "Delete goal button")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(isLoading || (targetDistanceValue ?? 0) <= 0 || isSaving)
                }
            }
            .alert("Delete Goal?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This goal will be permanently deleted.")
            }
            .task {
                await loadDefaultDistance()
            }
        }
    }

    private func loadDefaultDistance() async {
        guard targetDistanceValue == nil else {
            isLoading = false
            return
        }

        do {
            let latestGoal: RunningGoal?
            if goalType == .monthly {
                latestGoal = try await firestoreService.getLatestMonthlyGoal(userId: userId)
            } else {
                latestGoal = try await firestoreService.getLatestYearlyGoal(userId: userId)
            }
            let defaultKm = latestGoal?.targetDistanceKm ?? 100.0
            targetDistanceValue = UnitFormatter.convertDistance(defaultKm, useMetric: useMetric)
        } catch {
            targetDistanceValue = UnitFormatter.convertDistance(100.0, useMetric: useMetric)
        }
        isLoading = false
    }

    private func saveGoal() {
        isSaving = true

        let goal = RunningGoal(
            id: currentGoal?.id,
            type: goalType,
            year: year,
            month: month,
            targetDistanceKm: targetDistanceKm,
            createdAt: currentGoal?.createdAt ?? Date(),
            updatedAt: Date()
        )

        onSave(goal)
        dismiss()
    }
}

#Preview {
    GoalSettingsView(
        goalType: .monthly,
        year: 2026,
        month: 2,
        currentGoal: nil,
        userId: "preview-user",
        onSave: { _ in }
    )
}
