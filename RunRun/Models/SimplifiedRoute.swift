import Foundation

/// タイムラインサムネイル用の簡略化されたルートデータ
struct SimplifiedRoute: Equatable, Sendable {
    let coordinates: [Coordinate]
    let boundingBox: BoundingBox

    struct Coordinate: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    struct BoundingBox: Equatable, Sendable {
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

// MARK: - Nonisolated Codable（Approachable ConcurrencyによるMainActor推論を回避）

extension SimplifiedRoute.Coordinate: Codable {
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

extension SimplifiedRoute.BoundingBox: Codable {
    private enum CodingKeys: String, CodingKey {
        case minLat, maxLat, minLon, maxLon
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minLat = try container.decode(Double.self, forKey: .minLat)
        maxLat = try container.decode(Double.self, forKey: .maxLat)
        minLon = try container.decode(Double.self, forKey: .minLon)
        maxLon = try container.decode(Double.self, forKey: .maxLon)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minLat, forKey: .minLat)
        try container.encode(maxLat, forKey: .maxLat)
        try container.encode(minLon, forKey: .minLon)
        try container.encode(maxLon, forKey: .maxLon)
    }
}

extension SimplifiedRoute: Codable {
    private enum CodingKeys: String, CodingKey {
        case coordinates, boundingBox
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coordinates = try container.decode([Coordinate].self, forKey: .coordinates)
        boundingBox = try container.decode(BoundingBox.self, forKey: .boundingBox)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinates, forKey: .coordinates)
        try container.encode(boundingBox, forKey: .boundingBox)
    }
}
