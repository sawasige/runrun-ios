import SwiftUI

struct UserDetailView: View {
    let user: UserProfile
    let year: Int
    let month: Int

    @State private var records: [RunningRecord] = []
    @State private var isLoading = true
    @State private var error: Error?

    private let firestoreService = FirestoreService()

    private var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceInKilometers }
    }

    private var formattedTotalDistance: String {
        String(format: "%.1f km", totalDistance)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if records.isEmpty {
                emptyView
            } else {
                recordsList
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRuns()
        }
    }

    private var recordsList: some View {
        List {
            Section {
                HStack {
                    Text("合計")
                    Spacer()
                    Text(formattedTotalDistance)
                        .fontWeight(.bold)
                }
                HStack {
                    Text("回数")
                    Spacer()
                    Text("\(records.count)回")
                }
            }

            Section("ランニング記録") {
                ForEach(records) { record in
                    RunningRecordRow(record: record)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("この月のランニング記録はありません")
                .foregroundStyle(.secondary)
        }
    }

    private func loadRuns() async {
        guard let userId = user.id else { return }

        do {
            let runs = try await firestoreService.getUserMonthlyRuns(
                userId: userId,
                year: year,
                month: month
            )
            records = runs.map { RunningRecord(date: $0.date, distanceKm: $0.distanceKm, durationSeconds: $0.durationSeconds) }
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        UserDetailView(
            user: UserProfile(id: "test", displayName: "テストユーザー", email: nil),
            year: 2024,
            month: 12
        )
    }
}
