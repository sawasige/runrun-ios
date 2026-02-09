import Foundation
import CryptoKit
import CoreLocation
import HealthKit

actor RouteCacheService {
    static let shared = RouteCacheService()

    private let memoryCache = NSCache<NSString, CachedRoute>()
    private let cacheExpiration: TimeInterval = 86400 // 24時間
    private let cacheDirectory: URL
    private let healthKitService: HealthKitService

    private init() {
        memoryCache.countLimit = 50
        healthKitService = HealthKitService()

        // キャッシュディレクトリを作成
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("RouteCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 起動時に期限切れキャッシュを削除
        Task {
            await cleanupExpiredCache()
        }
    }

    // MARK: - Public API

    /// キャッシュまたはHealthKitからルートを取得
    func route(for runDate: Date, userId: String) async -> SimplifiedRoute? {
        let key = cacheKey(for: runDate, userId: userId)

        // 1. メモリキャッシュから取得
        if let cached = memoryCache.object(forKey: key as NSString) {
            if Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
                return cached.route
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // 2. ディスクキャッシュから取得
        if let (route, timestamp) = loadFromDisk(key: key) {
            if Date().timeIntervalSince(timestamp) < cacheExpiration {
                // メモリキャッシュにも保存
                let cached = CachedRoute(route: route, timestamp: timestamp)
                memoryCache.setObject(cached, forKey: key as NSString)
                return route
            } else {
                // 期限切れなので削除
                removeFromDisk(key: key)
            }
        }

        // 3. HealthKitから取得
        guard let route = await fetchAndSimplifyRoute(for: runDate) else {
            return nil
        }

        // キャッシュに保存
        let timestamp = Date()
        let cached = CachedRoute(route: route, timestamp: timestamp)
        memoryCache.setObject(cached, forKey: key as NSString)
        saveToDisk(key: key, route: route, timestamp: timestamp)

        return route
    }

    /// 複数ルートをプリフェッチ
    func prefetchRoutes(for runs: [(date: Date, userId: String)]) async {
        await withTaskGroup(of: Void.self) { group in
            for run in runs {
                group.addTask {
                    _ = await self.route(for: run.date, userId: run.userId)
                }
            }
        }
    }

    /// キャッシュクリア
    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private: HealthKit

    private func fetchAndSimplifyRoute(for runDate: Date) async -> SimplifiedRoute? {
        // ワークアウトを取得（runDateを含む短い範囲で検索）
        let startOfDay = Calendar.current.startOfDay(for: runDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let workouts = try await healthKitService.fetchAllRawRunningWorkouts()

            // runDateに最も近いワークアウトを探す
            guard let workout = workouts.first(where: {
                $0.startDate >= startOfDay && $0.startDate < endOfDay &&
                abs($0.startDate.timeIntervalSince(runDate)) < 60
            }) else {
                return nil
            }

            // ルートを取得
            let locations = await healthKitService.fetchWorkoutRoute(for: workout)
            guard locations.count >= 2 else { return nil }

            // 座標を簡略化
            return simplifyRoute(from: locations)
        } catch {
            return nil
        }
    }

    /// Douglas-Peucker法で座標を間引き
    private func simplifyRoute(from locations: [CLLocation]) -> SimplifiedRoute {
        let coordinates = locations.map {
            SimplifiedRoute.Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }

        // Douglas-Peucker法で間引き（epsilon = 0.0001 ≒ 約10m）
        let simplified = douglasPeucker(coordinates, epsilon: 0.0001)

        // BoundingBox計算
        let boundingBox = calculateBoundingBox(simplified)

        return SimplifiedRoute(coordinates: simplified, boundingBox: boundingBox)
    }

    /// Douglas-Peucker法による座標間引き
    private func douglasPeucker(_ points: [SimplifiedRoute.Coordinate], epsilon: Double) -> [SimplifiedRoute.Coordinate] {
        guard points.count > 2 else { return points }

        // 始点と終点を結ぶ直線から最も遠い点を探す
        var maxDistance: Double = 0
        var maxIndex = 0

        let start = points.first!
        let end = points.last!

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(points[i], from: start, to: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // 最大距離がepsilonより大きければ再帰的に処理
        if maxDistance > epsilon {
            let left = douglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(Array(points[maxIndex...]), epsilon: epsilon)

            // 重複する中間点を除いて結合
            return Array(left.dropLast()) + right
        } else {
            // 始点と終点のみ返す
            return [start, end]
        }
    }

    /// 点から直線への垂直距離
    private func perpendicularDistance(
        _ point: SimplifiedRoute.Coordinate,
        from start: SimplifiedRoute.Coordinate,
        to end: SimplifiedRoute.Coordinate
    ) -> Double {
        let dx = end.longitude - start.longitude
        let dy = end.latitude - start.latitude

        // 直線の長さが0の場合は始点からの距離を返す
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            let pdx = point.longitude - start.longitude
            let pdy = point.latitude - start.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        // 垂直距離を計算
        let numerator = abs(dy * point.longitude - dx * point.latitude + end.longitude * start.latitude - end.latitude * start.longitude)
        let denominator = sqrt(lengthSquared)
        return numerator / denominator
    }

    private func calculateBoundingBox(_ coordinates: [SimplifiedRoute.Coordinate]) -> SimplifiedRoute.BoundingBox {
        guard !coordinates.isEmpty else {
            return SimplifiedRoute.BoundingBox(minLat: 0, maxLat: 0, minLon: 0, maxLon: 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return SimplifiedRoute.BoundingBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    // MARK: - Private: Cache Key

    private func cacheKey(for runDate: Date, userId: String) -> String {
        let input = "\(userId)_\(runDate.timeIntervalSince1970)"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private: Disk Cache

    private func loadFromDisk(key: String) -> (SimplifiedRoute, Date)? {
        let routeURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        guard let routeData = try? Data(contentsOf: routeURL),
              let metaData = try? Data(contentsOf: metaURL),
              let route = try? JSONDecoder().decode(SimplifiedRoute.self, from: routeData),
              let timestamp = try? JSONDecoder().decode(Date.self, from: metaData) else {
            return nil
        }

        return (route, timestamp)
    }

    private func saveToDisk(key: String, route: SimplifiedRoute, timestamp: Date) {
        let routeURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        if let routeData = try? JSONEncoder().encode(route) {
            try? routeData.write(to: routeURL)
        }
        if let metaData = try? JSONEncoder().encode(timestamp) {
            try? metaData.write(to: metaURL)
        }
    }

    private func removeFromDisk(key: String) {
        let routeURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).meta")

        try? FileManager.default.removeItem(at: routeURL)
        try? FileManager.default.removeItem(at: metaURL)
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
                let routeURL = metaURL.deletingPathExtension()
                try? FileManager.default.removeItem(at: routeURL)
                continue
            }

            if Date().timeIntervalSince(timestamp) >= cacheExpiration {
                // 期限切れなので削除
                try? FileManager.default.removeItem(at: metaURL)
                let routeURL = metaURL.deletingPathExtension()
                try? FileManager.default.removeItem(at: routeURL)
            }
        }
    }
}

// MARK: - Cached Route Wrapper

private final class CachedRoute: @unchecked Sendable {
    let route: SimplifiedRoute
    let timestamp: Date

    nonisolated init(route: SimplifiedRoute, timestamp: Date) {
        self.route = route
        self.timestamp = timestamp
    }
}
