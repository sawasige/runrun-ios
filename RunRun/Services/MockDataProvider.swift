import Foundation
import CoreLocation

/// スクリーンショット用のモックデータを提供
struct MockDataProvider {

    // MARK: - 現在のユーザー

    static let currentUserId = "mock-current-user"

    static let currentUser = UserProfile(
        id: currentUserId,
        displayName: "山田 太郎",
        email: nil,
        iconName: "figure.run",
        avatarURL: nil,
        totalDistanceKm: 156.8,
        totalRuns: 28
    )

    // MARK: - タイムライン用

    static var timelineRuns: [TimelineRun] {
        let now = Date()
        return [
            TimelineRun(
                id: "run-1",
                date: now.addingTimeInterval(-3600),
                distanceKm: 5.23,
                durationSeconds: 1650,
                userId: "user-1",
                displayName: "佐藤 健",
                avatarURL: nil,
                iconName: "figure.run",
                caloriesBurned: 320,
                averageHeartRate: 152
            ),
            TimelineRun(
                id: "run-2",
                date: now.addingTimeInterval(-7200),
                distanceKm: 10.5,
                durationSeconds: 3300,
                userId: "user-2",
                displayName: "鈴木 花子",
                avatarURL: nil,
                iconName: "hare.fill",
                caloriesBurned: 650,
                averageHeartRate: 145
            ),
            TimelineRun(
                id: "run-3",
                date: now.addingTimeInterval(-86400),
                distanceKm: 7.8,
                durationSeconds: 2700,
                userId: currentUserId,
                displayName: currentUser.displayName,
                avatarURL: nil,
                iconName: "figure.run",
                caloriesBurned: 480,
                averageHeartRate: 148
            ),
            TimelineRun(
                id: "run-4",
                date: now.addingTimeInterval(-90000),
                distanceKm: 3.2,
                durationSeconds: 1080,
                userId: "user-3",
                displayName: "高橋 誠",
                avatarURL: nil,
                iconName: "bolt.fill",
                caloriesBurned: 195,
                averageHeartRate: 138
            ),
        ]
    }

    // MARK: - 月間記録用

    static var monthlyStats: [MonthlyRunningStats] {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        return (0..<12).map { offset in
            var components = DateComponents()
            components.year = currentYear
            components.month = currentMonth - offset

            let date = calendar.date(from: components) ?? now
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)

            let baseDistance = Double.random(in: 30000...80000)
            let runCount = Int.random(in: 5...15)

            return MonthlyRunningStats(
                id: UUID(),
                year: year,
                month: month,
                totalDistanceInMeters: baseDistance,
                totalDurationInSeconds: baseDistance / 1000 * 330, // 約5:30/km
                runCount: runCount
            )
        }
    }

    // MARK: - ランキング用

    static var leaderboardUsers: [UserProfile] {
        [
            UserProfile(id: "leader-1", displayName: "田中 一郎", email: nil, iconName: "hare.fill", totalDistanceKm: 185.3, totalRuns: 32),
            UserProfile(id: "leader-2", displayName: "山本 さくら", email: nil, iconName: "flame.fill", totalDistanceKm: 172.6, totalRuns: 28),
            UserProfile(id: currentUserId, displayName: currentUser.displayName, email: nil, iconName: "figure.run", totalDistanceKm: 156.8, totalRuns: 28),
            UserProfile(id: "leader-4", displayName: "伊藤 大輔", email: nil, iconName: "bolt.fill", totalDistanceKm: 142.1, totalRuns: 24),
            UserProfile(id: "leader-5", displayName: "渡辺 美咲", email: nil, iconName: "star.fill", totalDistanceKm: 128.5, totalRuns: 22),
            UserProfile(id: "leader-6", displayName: "小林 翔太", email: nil, iconName: "figure.run", totalDistanceKm: 115.2, totalRuns: 20),
            UserProfile(id: "leader-7", displayName: "加藤 恵", email: nil, iconName: "heart.fill", totalDistanceKm: 98.7, totalRuns: 18),
            UserProfile(id: "leader-8", displayName: "吉田 隆", email: nil, iconName: "mountain.2.fill", totalDistanceKm: 87.4, totalRuns: 15),
        ]
    }

    // MARK: - ラン詳細用（皇居一周）

    static var runDetail: RunningRecord {
        RunningRecord(
            id: UUID(),
            date: Date().addingTimeInterval(-3600),
            distanceInMeters: 5000,
            durationInSeconds: 1650,  // 5:30/km ペース
            caloriesBurned: 320,
            averageHeartRate: 152,
            maxHeartRate: 168,
            minHeartRate: 135,
            cadence: 175,
            strideLength: 1.05,
            stepCount: 5250
        )
    }

    /// 皇居一周のルートセグメント（グラデーション表示用）
    static var imperialPalaceRouteSegments: [RouteSegment] {
        // 皇居一周の座標（約5km、時計回り）
        let coordinates: [(lat: Double, lon: Double, pace: TimeInterval)] = [
            // 桜田門スタート
            (35.6762, 139.7527, 330), // 5:30
            (35.6755, 139.7545, 325),
            (35.6748, 139.7563, 320),
            // 二重橋前
            (35.6780, 139.7580, 315),
            (35.6795, 139.7595, 310), // 5:10 (速い)
            (35.6810, 139.7605, 305),
            // 大手門
            (35.6850, 139.7615, 300), // 5:00 (最速)
            (35.6870, 139.7610, 310),
            (35.6885, 139.7595, 320),
            // 竹橋
            (35.6905, 139.7570, 330),
            (35.6910, 139.7545, 340), // 5:40 (少し遅い)
            (35.6905, 139.7520, 350),
            // 北の丸公園横
            (35.6890, 139.7495, 360), // 6:00 (遅い - 上り坂)
            (35.6870, 139.7475, 355),
            (35.6850, 139.7465, 345),
            // 半蔵門
            (35.6830, 139.7470, 335),
            (35.6810, 139.7480, 325),
            (35.6790, 139.7495, 320),
            // 桜田門に戻る
            (35.6775, 139.7510, 315),
            (35.6762, 139.7527, 310), // ゴール
        ]

        // セグメントを生成（各ポイント間）
        var segments: [RouteSegment] = []
        for i in 0..<(coordinates.count - 1) {
            let start = coordinates[i]
            let end = coordinates[i + 1]

            // 途中ポイントを補間して滑らかなルートに
            var segmentCoords: [CLLocationCoordinate2D] = []
            for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                let lat = start.lat + (end.lat - start.lat) * t
                let lon = start.lon + (end.lon - start.lon) * t
                segmentCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }

            segments.append(RouteSegment(
                coordinates: segmentCoords,
                pacePerKm: start.pace
            ))
        }

        return segments
    }

    /// キロメーカーのポイント
    static var kilometerPoints: [KilometerPoint] {
        [
            KilometerPoint(kilometer: 1, coordinate: CLLocationCoordinate2D(latitude: 35.6810, longitude: 139.7605)),
            KilometerPoint(kilometer: 2, coordinate: CLLocationCoordinate2D(latitude: 35.6905, longitude: 139.7545)),
            KilometerPoint(kilometer: 3, coordinate: CLLocationCoordinate2D(latitude: 35.6850, longitude: 139.7465)),
            KilometerPoint(kilometer: 4, coordinate: CLLocationCoordinate2D(latitude: 35.6775, longitude: 139.7510)),
        ]
    }

    /// スタート地点
    static var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.7527)
    }

    /// ゴール地点
    static var goalCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.7527)
    }

    /// ペース範囲（グラデーション用）
    static var paceRange: (fast: TimeInterval, slow: TimeInterval) {
        (300, 360) // 5:00 〜 6:00
    }

    // MARK: - 月詳細用

    static var monthDetailRecords: [RunningRecord] {
        let now = Date()
        return (0..<10).map { i in
            let date = now.addingTimeInterval(Double(-i * 86400 * 2))
            let distance = Double.random(in: 3000...12000)
            return RunningRecord(
                id: UUID(),
                date: date,
                distanceInMeters: distance,
                durationInSeconds: distance / 1000 * Double.random(in: 300...400),
                caloriesBurned: distance / 15,
                averageHeartRate: Double.random(in: 140...160),
                maxHeartRate: Double.random(in: 165...180),
                minHeartRate: Double.random(in: 120...140)
            )
        }
    }
}

// MARK: - キロマーカー用構造体

struct KilometerPoint: Identifiable {
    let id = UUID()
    let kilometer: Int
    let coordinate: CLLocationCoordinate2D
}
