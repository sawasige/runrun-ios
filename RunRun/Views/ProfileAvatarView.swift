import SwiftUI

struct ProfileAvatarView: View {
    let iconName: String
    let avatarURL: URL?
    let size: CGFloat

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
            if let avatarURL = avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        iconView
                    @unknown default:
                        iconView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                iconView
            }
        }
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Color.blue)
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
