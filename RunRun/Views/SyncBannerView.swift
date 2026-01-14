import SwiftUI

struct SyncBannerView: View {
    @ObservedObject var syncService: SyncService
    let userId: String
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isVisible {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onChange(of: syncService.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onAppear {
            // 初期状態でも同期中なら表示
            if syncService.isSyncing {
                isVisible = true
            }
        }
    }

    @ViewBuilder
    private var bannerContent: some View {
        HStack(spacing: 12) {
            switch syncService.phase {
            case .idle:
                EmptyView()

            case .connecting, .fetching:
                ProgressView()
                    .scaleEffect(0.8)
                Text(syncService.phase.message)
                    .font(.subheadline)

            case .syncing(let current, let total):
                ProgressView()
                    .scaleEffect(0.8)
                Text(syncService.phase.message)
                    .font(.subheadline)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .completed(let count):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if count > 0 {
                    Text(String(format: String(localized: "%d new records synced"), count))
                        .font(.subheadline)
                } else {
                    Text("Already synced")
                        .font(.subheadline)
                }

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Sync failed")
                    .font(.subheadline)
                Spacer()
                Button {
                    Task {
                        await syncService.syncHealthKitData(userId: userId)
                    }
                } label: {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
    }

    private func handlePhaseChange(_ phase: SyncPhase) {
        hideTask?.cancel()

        switch phase {
        case .idle:
            isVisible = false

        case .connecting, .fetching, .syncing:
            isVisible = true

        case .completed:
            isVisible = true
            // 3秒後に自動で非表示
            hideTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    withAnimation {
                        isVisible = false
                    }
                }
            }

        case .failed:
            isVisible = true
        }
    }
}

#Preview {
    VStack {
        SyncBannerView(syncService: SyncService(), userId: "preview")
        Spacer()
    }
}
