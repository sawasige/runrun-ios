import Foundation
import CoreLocation
import SwiftUI

struct RouteSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let pacePerKm: TimeInterval

    /// ペース範囲に基づいてグラデーション色を返す
    /// - Parameters:
    ///   - fastPace: 速いペースの基準（秒/km、10パーセンタイル推奨）
    ///   - slowPace: 遅いペースの基準（秒/km、90パーセンタイル推奨）
    func color(fastPace: TimeInterval, slowPace: TimeInterval) -> Color {
        guard slowPace > fastPace else { return .yellow }

        // 0.0（最速）〜 1.0（最遅）に正規化、範囲外はクランプ
        let normalized = min(1.0, max(0.0, (pacePerKm - fastPace) / (slowPace - fastPace)))

        // HSB色空間でグラデーション: 緑(0.33) → 黄(0.17) → 赤(0.0)
        let hue = 0.33 * (1.0 - normalized)
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }

    /// 最速ペースと90パーセンタイルを計算（下位10%の遅いセグメントを無視）
    static func calculatePacePercentiles(from segments: [RouteSegment]) -> (fast: TimeInterval, slow: TimeInterval) {
        let paces = segments.map(\.pacePerKm)
        guard !paces.isEmpty else {
            return (300, 600)
        }

        let minPace = paces.min() ?? 300

        guard segments.count >= 10 else {
            return (minPace, paces.max() ?? 600)
        }

        let sortedPaces = paces.sorted()
        let p90Index = sortedPaces.count * 9 / 10

        return (minPace, sortedPaces[p90Index])
    }
}
