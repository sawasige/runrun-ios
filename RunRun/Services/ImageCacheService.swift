import SwiftUI
import CryptoKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, CachedUIImage>()
    private let cacheExpiration: TimeInterval = 3600 // 1時間
    private let cacheDirectory: URL

    private init() {
        memoryCache.countLimit = 100

        // キャッシュディレクトリを作成
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 起動時に期限切れキャッシュを削除
        Task {
            await cleanupExpiredCache()
        }
    }

    private func cleanupExpiredCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        let metaFiles = files.filter { $0.pathExtension == "meta" }

        for metaURL in metaFiles {
            guard let metaData = try? Data(contentsOf: metaURL),
                  let timestamp = try? JSONDecoder().decode(Date.self, from: metaData) else {
                // メタデータが読めない場合は削除
                try? FileManager.default.removeItem(at: metaURL)
                let imageURL = metaURL.deletingPathExtension()
                try? FileManager.default.removeItem(at: imageURL)
                continue
            }

            if Date().timeIntervalSince(timestamp) >= cacheExpiration {
                // 期限切れなので削除
                try? FileManager.default.removeItem(at: metaURL)
                let imageURL = metaURL.deletingPathExtension()
                try? FileManager.default.removeItem(at: imageURL)
            }
        }
    }

    func image(for url: URL) async -> Image? {
        let key = cacheKey(for: url)

        // 1. メモリキャッシュから取得
        if let cached = memoryCache.object(forKey: key as NSString) {
            if Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
                return Image(uiImage: cached.uiImage)
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // 2. ディスクキャッシュから取得
        if let (uiImage, timestamp) = loadFromDisk(key: key) {
            if Date().timeIntervalSince(timestamp) < cacheExpiration {
                // メモリキャッシュにも保存
                let cached = CachedUIImage(uiImage: uiImage, timestamp: timestamp)
                memoryCache.setObject(cached, forKey: key as NSString)
                return Image(uiImage: uiImage)
            } else {
                // 期限切れなので削除
                removeFromDisk(key: key)
            }
        }

        // 3. ネットワークから取得
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return nil }
            let timestamp = Date()

            // メモリキャッシュに保存
            let cached = CachedUIImage(uiImage: uiImage, timestamp: timestamp)
            memoryCache.setObject(cached, forKey: key as NSString)

            // ディスクキャッシュに保存
            saveToDisk(key: key, data: data, timestamp: timestamp)

            return Image(uiImage: uiImage)
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

    private func loadFromDisk(key: String) -> (UIImage, Date)? {
        let imageURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        guard let data = try? Data(contentsOf: imageURL),
              let metaData = try? Data(contentsOf: metaURL),
              let timestamp = try? JSONDecoder().decode(Date.self, from: metaData),
              let uiImage = UIImage(data: data) else {
            return nil
        }

        return (uiImage, timestamp)
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

// UIImageを保持するクラス（Sendable対応）
private final class CachedUIImage: @unchecked Sendable {
    let uiImage: UIImage
    let timestamp: Date

    nonisolated init(uiImage: UIImage, timestamp: Date) {
        self.uiImage = uiImage
        self.timestamp = timestamp
    }
}
