import SwiftUI
import Lottie

/// Lottieアニメーションを表示するSwiftUIビュー
struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let animationView = LottieAnimationView()
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // .lottie または .json ファイルを読み込み
        if let dotLottieUrl = Bundle.main.url(forResource: animationName, withExtension: "lottie") {
            Task {
                do {
                    let dotLottieFile = try await DotLottieFile.loadedFrom(url: dotLottieUrl)
                    await MainActor.run {
                        animationView.loadAnimation(from: dotLottieFile)
                        animationView.loopMode = loopMode
                        animationView.play()
                    }
                } catch {
                    print("Failed to load dotLottie: \(error)")
                }
            }
        } else {
            animationView.animation = LottieAnimation.named(animationName)
            animationView.play()
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let animationView = uiView.subviews.first as? LottieAnimationView {
            if !animationView.isAnimationPlaying {
                animationView.play()
            }
        }
    }
}

#Preview {
    LottieView(animationName: "running")
        .frame(width: 50, height: 50)
}
