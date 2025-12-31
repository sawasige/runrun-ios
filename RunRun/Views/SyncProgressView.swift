import SwiftUI

struct SyncProgressView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("ランニングデータを同期中...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SyncProgressView()
}
