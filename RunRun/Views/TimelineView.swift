import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var showNavBarLogo = false

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

    private var expandedHeaderView: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 50)

            Text("RunRun")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.frame(in: .global).maxY) { oldValue, newValue in
                        let threshold: CGFloat = 100
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNavBarLogo = newValue < threshold
                        }
                    }
            }
        )
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
        ScrollView {
            LazyVStack(spacing: 0) {
                expandedHeaderView

                ForEach(viewModel.dayGroups) { group in
                    sectionHeader(title: group.formattedDate)

                    ForEach(group.runs) { run in
                        NavigationLink {
                            RunDetailView(
                                record: run.toRunningRecord(),
                                isOwnRecord: run.userId == viewModel.userId
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
