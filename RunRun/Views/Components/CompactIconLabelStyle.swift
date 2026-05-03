import SwiftUI

struct CompactIconLabelStyle: LabelStyle {
    var spacing: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
