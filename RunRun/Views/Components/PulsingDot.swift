import SwiftUI

/// グラフの終点に表示する点滅ドット（HDR対応）
struct PulsingDot: View {
    @State private var phase = false

    private let brightColor = Color(red: 1.5, green: 0.4, blue: 0.4) // HDR対応の明るい色

    var body: some View {
        Circle()
            .fill(phase ? brightColor : Color.accentColor)
            .frame(width: 6, height: 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
    }
}

#Preview {
    PulsingDot()
        .padding(50)
        .background(Color.black)
}
