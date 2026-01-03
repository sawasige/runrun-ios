import SwiftUI

struct SyncProgressView: View {
    @ObservedObject var syncService: SyncService

    var body: some View {
        VStack(spacing: 32) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)

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
