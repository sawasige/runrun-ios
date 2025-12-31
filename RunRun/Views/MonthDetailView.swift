import SwiftUI

struct MonthDetailView: View {
    @StateObject private var viewModel: MonthDetailViewModel
    let userProfile: UserProfile?

    init(userId: String, year: Int, month: Int) {
        self.userProfile = nil
        _viewModel = StateObject(wrappedValue: MonthDetailViewModel(userId: userId, year: year, month: month))
    }

    init(user: UserProfile, year: Int, month: Int) {
        self.userProfile = user
        _viewModel = StateObject(wrappedValue: MonthDetailViewModel(userId: user.id ?? "", year: year, month: month))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.records.isEmpty {
                emptyView
            } else {
                recordsList
            }
        }
        .navigationTitle(viewModel.title)
        .toolbar {
            if let user = userProfile {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    private var recordsList: some View {
        List {
            if let user = userProfile {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatarView(user: user, size: 50)

                        Text(user.displayName)
                            .font(.headline)

                        Spacer()
                    }
                }
            }

            Section {
                HStack {
                    Text("合計")
                    Spacer()
                    Text(viewModel.formattedTotalDistance)
                        .fontWeight(.bold)
                }
                HStack {
                    Text("回数")
                    Spacer()
                    Text("\(viewModel.records.count)回")
                }
            }

            Section("ランニング記録") {
                ForEach(viewModel.records) { record in
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
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
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
