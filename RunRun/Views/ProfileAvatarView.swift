import SwiftUI

struct ProfileAvatarView: View {
    let iconName: String
    let avatarURL: URL?
    let size: CGFloat

    @State private var cachedImage: Image?
    @State private var isLoading = false

    init(user: UserProfile, size: CGFloat = 40) {
        self.iconName = user.iconName
        self.avatarURL = user.avatarURL
        self.size = size
    }

    init(iconName: String, avatarURL: URL? = nil, size: CGFloat = 40) {
        self.iconName = iconName
        self.avatarURL = avatarURL
        self.size = size
    }

    var body: some View {
        Group {
            if let image = cachedImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                iconView
            }
        }
        .task(id: avatarURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = avatarURL else { return }
        isLoading = true
        cachedImage = await ImageCacheService.shared.image(for: url)
        isLoading = false
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileAvatarView(iconName: "figure.run", size: 60)
        ProfileAvatarView(iconName: "hare.fill", size: 40)
    }
}
