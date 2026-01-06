import SwiftUI
import CryptoKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, CachedImage>()
    private let cacheExpiration: TimeInterval = 3600 // 1時間
    private let cacheDirectory: URL

    private init() {
        memoryCache.countLimit = 100

        // キャッシュディレクトリを作成
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> Image? {
        let key = cacheKey(for: url)

        // 1. メモリキャッシュから取得
        if let cached = memoryCache.object(forKey: key as NSString) {
            if Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
                return cached.image
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // 2. ディスクキャッシュから取得
        if let (image, timestamp) = loadFromDisk(key: key) {
            if Date().timeIntervalSince(timestamp) < cacheExpiration {
                // メモリキャッシュにも保存
                let cachedImage = CachedImage(image: image, timestamp: timestamp)
                memoryCache.setObject(cachedImage, forKey: key as NSString)
                return image
            } else {
                // 期限切れなので削除
                removeFromDisk(key: key)
            }
        }

        // 3. ネットワークから取得
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return nil }
            let image = Image(uiImage: uiImage)
            let timestamp = Date()

            // メモリキャッシュに保存
            let cachedImage = CachedImage(image: image, timestamp: timestamp)
            memoryCache.setObject(cachedImage, forKey: key as NSString)

            // ディスクキャッシュに保存
            saveToDisk(key: key, data: data, timestamp: timestamp)

            return image
        } catch {
            return nil
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func cacheKey(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk(key: String) -> (Image, Date)? {
        let imageURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        guard let data = try? Data(contentsOf: imageURL),
              let metaData = try? Data(contentsOf: metaURL),
              let timestamp = try? JSONDecoder().decode(Date.self, from: metaData),
              let uiImage = UIImage(data: data) else {
            return nil
        }

        return (Image(uiImage: uiImage), timestamp)
    }

    private func saveToDisk(key: String, data: Data, timestamp: Date) {
        let imageURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        try? data.write(to: imageURL)
        if let metaData = try? JSONEncoder().encode(timestamp) {
            try? metaData.write(to: metaURL)
        }
    }

    private func removeFromDisk(key: String) {
        let imageURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: metaURL)
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
