import Foundation

/// ランニング目標
struct RunningGoal: Identifiable, Equatable {
    var id: String?
    let type: GoalType
    let year: Int
    let month: Int?
    var targetDistanceKm: Double
    let createdAt: Date
    var updatedAt: Date

    enum GoalType: String, Codable {
        case monthly
        case yearly
    }

    /// 進捗率を計算（0.0〜1.0+）
    func progress(currentDistanceKm: Double) -> Double {
        guard targetDistanceKm > 0 else { return 0 }
        return currentDistanceKm / targetDistanceKm
    }

    /// 目標達成済みかどうか
    func isAchieved(currentDistanceKm: Double) -> Bool {
        currentDistanceKm >= targetDistanceKm
    }

    /// 目標距離をユーザー設定の単位でフォーマット
    func formattedTargetDistance(useMetric: Bool) -> String {
        UnitFormatter.formatDistance(targetDistanceKm, useMetric: useMetric, decimals: 1)
    }

    /// 目標距離をユーザー設定の単位で変換（数値のみ）
    func targetDistance(useMetric: Bool) -> Double {
        UnitFormatter.convertDistance(targetDistanceKm, useMetric: useMetric)
    }
}
