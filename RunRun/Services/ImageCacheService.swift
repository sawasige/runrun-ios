import SwiftUI

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSString, CachedImage>()
    private let cacheExpiration: TimeInterval = 3600 // 1時間

    private init() {
        cache.countLimit = 100
    }

    func image(for url: URL) async -> Image? {
        let key = url.absoluteString as NSString

        // キャッシュから取得
        if let cached = cache.object(forKey: key) {
            if Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
                return cached.image
            } else {
                cache.removeObject(forKey: key)
            }
        }

        // ネットワークから取得
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return nil }
            let image = Image(uiImage: uiImage)

            // キャッシュに保存
            let cachedImage = CachedImage(image: image, timestamp: Date())
            cache.setObject(cachedImage, forKey: key)

            return image
        } catch {
            return nil
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

private final class CachedImage {
    let image: Image
    let timestamp: Date

    init(image: Image, timestamp: Date) {
        self.image = image
        self.timestamp = timestamp
    }
}
