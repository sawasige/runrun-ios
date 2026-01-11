import SwiftUI
import UIKit

struct ShineLogoView: UIViewRepresentable {
    let size: CGFloat

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        guard let logoImage = UIImage(named: "Logo") else { return container }

        // ロゴ画像
        let imageView = UIImageView(image: logoImage)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 0, y: 0, width: size, height: size)
        container.addSubview(imageView)

        // シャインオーバーレイ（ロゴの形でマスク）
        let shineContainer = UIView()
        shineContainer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        shineContainer.clipsToBounds = true

        // マスク用のロゴ画像
        let maskImageView = UIImageView(image: logoImage)
        maskImageView.contentMode = .scaleAspectFit
        maskImageView.frame = shineContainer.bounds
        shineContainer.mask = maskImageView

        container.addSubview(shineContainer)

        // シャインレイヤー
        let shineLayer = CAGradientLayer()
        shineLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        shineLayer.locations = [0, 0.5, 1]
        shineLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shineLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shineLayer.frame = CGRect(x: -size, y: 0, width: size * 0.5, height: size)

        shineContainer.layer.addSublayer(shineLayer)

        // シャインアニメーション（速く通過、長い間隔）
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = -size * 0.25
        animation.toValue = size * 1.25
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let group = CAAnimationGroup()
        group.animations = [animation]
        group.duration = 2.5  // 0.5秒アニメ + 2秒待機
        group.repeatCount = .infinity

        shineLayer.add(group, forKey: "shine")

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    ShineLogoView(size: 80)
        .frame(width: 80, height: 80)
}
