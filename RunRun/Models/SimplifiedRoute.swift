import Foundation

/// タイムラインサムネイル用の簡略化されたルートデータ
struct SimplifiedRoute: Codable, Equatable, Sendable {
    let coordinates: [Coordinate]
    let boundingBox: BoundingBox

    struct Coordinate: Codable, Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    struct BoundingBox: Codable, Equatable, Sendable {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double

        var latSpan: Double { maxLat - minLat }
        var lonSpan: Double { maxLon - minLon }
        var centerLat: Double { (minLat + maxLat) / 2 }
        var centerLon: Double { (minLon + maxLon) / 2 }
    }
}
