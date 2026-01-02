import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel

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
            .navigationTitle("タイムライン")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    logoView
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.onAppear()
            }
        }
    }

    private var logoView: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 28)
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
        List {
            ForEach(viewModel.dayGroups) { group in
                Section(group.formattedDate) {
                    ForEach(group.runs) { run in
                        TimelineRunRow(run: run)
                    }
                }
            }

            if viewModel.hasMore {
                HStack {
                    Spacer()
                    if viewModel.isLoadingMore {
                        ProgressView()
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
        .listStyle(.insetGrouped)
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TimelineView(userId: "preview")
}
