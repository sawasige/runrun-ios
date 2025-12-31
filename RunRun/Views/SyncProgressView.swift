import SwiftUI

struct SyncProgressView: View {
    @ObservedObject var syncService: SyncService

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 16) {
                ProgressView(value: syncService.phase.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text(syncService.phase.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SyncProgressView(syncService: SyncService())
}
