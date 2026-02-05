import SwiftUI

/// チャート用ツールチップ（月詳細・年詳細・プロフィールで共通使用）
struct ChartTooltip: View {
    let title: String
    let value: String
    var previousValue: String?
    var previousLabel: String?
    var onTap: (() -> Void)?

    private var isTappable: Bool {
        onTap != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.identity)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .contentTransition(.identity)
                if let previousValue, let previousLabel {
                    HStack(spacing: 2) {
                        Text(previousLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(previousValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .contentTransition(.identity)
                    }
                }
            }

            if isTappable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isTappable ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            onTap?()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ChartTooltip(title: "1月", value: "123.4 km")
        ChartTooltip(title: "1月", value: "123.4 km", previousValue: "100.0 km", previousLabel: "前月")
        ChartTooltip(title: "1月", value: "123.4 km", onTap: {})
        ChartTooltip(title: "1月", value: "123.4 km", previousValue: "100.0 km", previousLabel: "前年", onTap: {})
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
