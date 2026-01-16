import Foundation
import CoreLocation

/// スクリーンショット用のモックデータを提供
struct MockDataProvider {

    // MARK: - 言語判定

    private static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }

    // MARK: - 現在のユーザー

    static let currentUserId = "mock-current-user"

    static var currentUser: UserProfile {
        UserProfile(
            id: currentUserId,
            displayName: isEnglish ? "John Smith" : "山田 太郎",
            email: nil,
            iconName: "figure.run",
            avatarURL: nil,
            totalDistanceKm: 156.8,
            totalRuns: 28
        )
    }

    // MARK: - タイムライン用（約1週間分、20件）

    private static func name(_ ja: String, _ en: String) -> String {
        isEnglish ? en : ja
    }

    static var timelineRuns: [TimelineRun] {
        let now = Date()
        return [
            // 今日
            TimelineRun(id: "run-1", date: now.addingTimeInterval(-1800), distanceKm: 5.23, durationSeconds: 1650, userId: "user-1", displayName: name("佐藤 健", "Mike Johnson"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 320, averageHeartRate: 152),
            TimelineRun(id: "run-2", date: now.addingTimeInterval(-5400), distanceKm: 10.5, durationSeconds: 3300, userId: "user-2", displayName: name("鈴木 花子", "Sarah Williams"), avatarURL: nil, iconName: "hare.fill", caloriesBurned: 650, averageHeartRate: 145),
            TimelineRun(id: "run-3", date: now.addingTimeInterval(-10800), distanceKm: 7.8, durationSeconds: 2700, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 480, averageHeartRate: 148),
            // 昨日
            TimelineRun(id: "run-4", date: now.addingTimeInterval(-86400 - 3600), distanceKm: 3.2, durationSeconds: 1080, userId: "user-3", displayName: name("高橋 誠", "David Brown"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 195, averageHeartRate: 138),
            TimelineRun(id: "run-5", date: now.addingTimeInterval(-86400 - 10800), distanceKm: 8.1, durationSeconds: 2580, userId: "user-4", displayName: name("中村 愛", "Emily Davis"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 510, averageHeartRate: 155),
            TimelineRun(id: "run-6", date: now.addingTimeInterval(-86400 - 18000), distanceKm: 6.5, durationSeconds: 2100, userId: "user-5", displayName: name("松本 翔", "Chris Miller"), avatarURL: nil, iconName: "flame.fill", caloriesBurned: 410, averageHeartRate: 148),
            // 2日前
            TimelineRun(id: "run-7", date: now.addingTimeInterval(-172800 - 7200), distanceKm: 12.3, durationSeconds: 4020, userId: "user-6", displayName: name("井上 真央", "Jessica Wilson"), avatarURL: nil, iconName: "star.fill", caloriesBurned: 780, averageHeartRate: 142),
            TimelineRun(id: "run-8", date: now.addingTimeInterval(-172800 - 14400), distanceKm: 4.8, durationSeconds: 1560, userId: "user-7", displayName: name("木村 拓也", "Ryan Taylor"), avatarURL: nil, iconName: "mountain.2.fill", caloriesBurned: 300, averageHeartRate: 140),
            TimelineRun(id: "run-9", date: now.addingTimeInterval(-172800 - 21600), distanceKm: 9.2, durationSeconds: 2940, userId: "user-8", displayName: name("斉藤 美穂", "Amanda Anderson"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 580, averageHeartRate: 150),
            // 3日前
            TimelineRun(id: "run-10", date: now.addingTimeInterval(-259200 - 3600), distanceKm: 5.5, durationSeconds: 1800, userId: "user-9", displayName: name("森田 康平", "Kevin Thomas"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 345, averageHeartRate: 144),
            TimelineRun(id: "run-11", date: now.addingTimeInterval(-259200 - 10800), distanceKm: 7.0, durationSeconds: 2310, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 440, averageHeartRate: 146),
            TimelineRun(id: "run-12", date: now.addingTimeInterval(-259200 - 18000), distanceKm: 4.2, durationSeconds: 1380, userId: "user-10", displayName: name("藤井 沙織", "Lauren Martinez"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 265, averageHeartRate: 138),
            // 4日前
            TimelineRun(id: "run-13", date: now.addingTimeInterval(-345600 - 7200), distanceKm: 15.0, durationSeconds: 4800, userId: "user-11", displayName: name("西村 大地", "Daniel Garcia"), avatarURL: nil, iconName: "hare.fill", caloriesBurned: 950, averageHeartRate: 152),
            TimelineRun(id: "run-14", date: now.addingTimeInterval(-345600 - 14400), distanceKm: 6.8, durationSeconds: 2200, userId: "user-12", displayName: name("山口 理恵", "Rachel Lee"), avatarURL: nil, iconName: "star.fill", caloriesBurned: 425, averageHeartRate: 142),
            // 5日前
            TimelineRun(id: "run-15", date: now.addingTimeInterval(-432000 - 3600), distanceKm: 8.5, durationSeconds: 2720, userId: "user-13", displayName: name("清水 隆司", "Brandon Clark"), avatarURL: nil, iconName: "flame.fill", caloriesBurned: 535, averageHeartRate: 148),
            TimelineRun(id: "run-16", date: now.addingTimeInterval(-432000 - 10800), distanceKm: 5.0, durationSeconds: 1650, userId: "user-14", displayName: name("長谷川 由美", "Megan White"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 315, averageHeartRate: 140),
            TimelineRun(id: "run-17", date: now.addingTimeInterval(-432000 - 18000), distanceKm: 11.2, durationSeconds: 3640, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 705, averageHeartRate: 150),
            // 6日前
            TimelineRun(id: "run-18", date: now.addingTimeInterval(-518400 - 7200), distanceKm: 3.8, durationSeconds: 1260, userId: "user-15", displayName: name("岡田 健一", "Justin Harris"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 240, averageHeartRate: 136),
            TimelineRun(id: "run-19", date: now.addingTimeInterval(-518400 - 14400), distanceKm: 7.5, durationSeconds: 2475, userId: "user-16", displayName: name("前田 あかり", "Nicole Robinson"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 470, averageHeartRate: 144),
            // 7日前
            TimelineRun(id: "run-20", date: now.addingTimeInterval(-604800 - 3600), distanceKm: 6.2, durationSeconds: 2046, userId: "user-17", displayName: name("石田 誠司", "Andrew Lewis"), avatarURL: nil, iconName: "mountain.2.fill", caloriesBurned: 390, averageHeartRate: 142),
        ]
    }

    // MARK: - 月間記録用

    static var monthlyStats: [MonthlyRunningStats] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // 今年の12ヶ月分を表示（1〜8月にデータあり、9〜12月は0）
        return (1...12).map { month in
            if month <= 8 {
                let baseDistance = Double.random(in: 30000...80000)
                let runCount = Int.random(in: 5...15)
                return MonthlyRunningStats(
                    id: UUID(),
                    year: currentYear,
                    month: month,
                    totalDistanceInMeters: baseDistance,
                    totalDurationInSeconds: baseDistance / 1000 * 330,
                    runCount: runCount,
                    totalCalories: baseDistance / 1000 * 60
                )
            } else {
                return MonthlyRunningStats(
                    id: UUID(),
                    year: currentYear,
                    month: month,
                    totalDistanceInMeters: 0,
                    totalDurationInSeconds: 0,
                    runCount: 0,
                    totalCalories: 0
                )
            }
        }
    }

    // MARK: - ランキング用（20件）

    static var leaderboardUsers: [UserProfile] {
        [
            UserProfile(id: "leader-1", displayName: name("田中 一郎", "James Wilson"), email: nil, iconName: "hare.fill", totalDistanceKm: 245.8, totalRuns: 42),
            UserProfile(id: "leader-2", displayName: name("山本 さくら", "Emma Thompson"), email: nil, iconName: "flame.fill", totalDistanceKm: 228.3, totalRuns: 38),
            UserProfile(id: "leader-3", displayName: name("佐藤 健太", "Michael Brown"), email: nil, iconName: "bolt.fill", totalDistanceKm: 215.6, totalRuns: 36),
            UserProfile(id: "leader-4", displayName: name("鈴木 美穂", "Olivia Davis"), email: nil, iconName: "star.fill", totalDistanceKm: 198.2, totalRuns: 34),
            UserProfile(id: "leader-5", displayName: name("高橋 大輔", "William Johnson"), email: nil, iconName: "figure.run", totalDistanceKm: 185.3, totalRuns: 32),
            UserProfile(id: currentUserId, displayName: currentUser.displayName, email: nil, iconName: "figure.run", totalDistanceKm: 156.8, totalRuns: 28),
            UserProfile(id: "leader-7", displayName: name("伊藤 翔太", "Alexander Miller"), email: nil, iconName: "heart.fill", totalDistanceKm: 148.5, totalRuns: 26),
            UserProfile(id: "leader-8", displayName: name("渡辺 愛", "Sophia Garcia"), email: nil, iconName: "flame.fill", totalDistanceKm: 142.1, totalRuns: 24),
            UserProfile(id: "leader-9", displayName: name("小林 誠", "Benjamin Martinez"), email: nil, iconName: "hare.fill", totalDistanceKm: 135.7, totalRuns: 23),
            UserProfile(id: "leader-10", displayName: name("加藤 由美", "Isabella Anderson"), email: nil, iconName: "star.fill", totalDistanceKm: 128.5, totalRuns: 22),
            UserProfile(id: "leader-11", displayName: name("吉田 隆司", "Ethan Taylor"), email: nil, iconName: "mountain.2.fill", totalDistanceKm: 121.3, totalRuns: 21),
            UserProfile(id: "leader-12", displayName: name("山口 恵子", "Charlotte Thomas"), email: nil, iconName: "bolt.fill", totalDistanceKm: 115.2, totalRuns: 20),
            UserProfile(id: "leader-13", displayName: name("松本 拓也", "Mason Moore"), email: nil, iconName: "figure.run", totalDistanceKm: 108.8, totalRuns: 19),
            UserProfile(id: "leader-14", displayName: name("井上 沙織", "Amelia Jackson"), email: nil, iconName: "heart.fill", totalDistanceKm: 102.4, totalRuns: 18),
            UserProfile(id: "leader-15", displayName: name("木村 康平", "Lucas White"), email: nil, iconName: "flame.fill", totalDistanceKm: 96.1, totalRuns: 17),
            UserProfile(id: "leader-16", displayName: name("斉藤 あかり", "Harper Harris"), email: nil, iconName: "hare.fill", totalDistanceKm: 89.7, totalRuns: 16),
            UserProfile(id: "leader-17", displayName: name("清水 大地", "Noah Martin"), email: nil, iconName: "star.fill", totalDistanceKm: 83.4, totalRuns: 15),
            UserProfile(id: "leader-18", displayName: name("森田 理恵", "Evelyn Thompson"), email: nil, iconName: "mountain.2.fill", totalDistanceKm: 77.2, totalRuns: 14),
            UserProfile(id: "leader-19", displayName: name("藤井 健一", "Liam Robinson"), email: nil, iconName: "bolt.fill", totalDistanceKm: 71.0, totalRuns: 13),
            UserProfile(id: "leader-20", displayName: name("西村 美咲", "Ava Clark"), email: nil, iconName: "figure.run", totalDistanceKm: 65.3, totalRuns: 12),
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
        // GPXファイルから抽出した皇居ランニングルート（詳細版）
        let coordinates: [(lat: Double, lon: Double, pace: TimeInterval)] = [
            // スタート（竹橋付近）
            (35.6908, 139.7561, 330),
            (35.6905, 139.7559, 328),
            (35.6903, 139.7554, 325),
            (35.6899, 139.7547, 322),
            (35.6895, 139.7538, 320),
            (35.6892, 139.7530, 318),
            (35.6893, 139.7523, 315),
            (35.6894, 139.7516, 312),
            (35.6891, 139.7508, 310),
            (35.6888, 139.7500, 308),
            // 北の丸公園横
            (35.6885, 139.7494, 305),
            (35.6883, 139.7488, 303),
            (35.6882, 139.7484, 300),
            (35.6880, 139.7478, 298),
            (35.6879, 139.7467, 300),
            (35.6880, 139.7460, 302),
            (35.6878, 139.7452, 305),
            (35.6870, 139.7450, 308),
            (35.6865, 139.7448, 310),
            (35.6856, 139.7446, 312),
            // 千鳥ヶ淵
            (35.6852, 139.7446, 315),
            (35.6845, 139.7444, 318),
            (35.6839, 139.7443, 320),
            (35.6830, 139.7444, 322),
            (35.6819, 139.7447, 325),
            (35.6809, 139.7454, 328),
            (35.6801, 139.7458, 330),
            (35.6797, 139.7466, 328),
            (35.6793, 139.7476, 325),
            (35.6787, 139.7482, 322),
            // 半蔵門
            (35.6778, 139.7490, 320),
            (35.6775, 139.7498, 318),
            (35.6774, 139.7511, 315),
            (35.6777, 139.7520, 312),
            (35.6781, 139.7534, 310),
            (35.6776, 139.7546, 308),
            // 桜田門〜二重橋
            (35.6771, 139.7556, 310),
            (35.6777, 139.7562, 312),
            (35.6786, 139.7567, 315),
            (35.6791, 139.7571, 318),
            (35.6794, 139.7573, 320),
            (35.6803, 139.7579, 322),
            (35.6810, 139.7584, 325),
            (35.6816, 139.7588, 328),
            (35.6823, 139.7592, 330),
            // 大手門方面
            (35.6830, 139.7597, 332),
            (35.6838, 139.7600, 335),
            (35.6847, 139.7603, 338),
            (35.6853, 139.7607, 340),
            (35.6858, 139.7610, 342),
            // ゴール（竹橋付近に戻る）
            (35.6866, 139.7613, 340),
            (35.6880, 139.7610, 338),
            (35.6890, 139.7605, 335),
            (35.6899, 139.7598, 332),
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
            KilometerPoint(kilometer: 1, coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.7446)),
            KilometerPoint(kilometer: 2, coordinate: CLLocationCoordinate2D(latitude: 35.6778, longitude: 139.7490)),
            KilometerPoint(kilometer: 3, coordinate: CLLocationCoordinate2D(latitude: 35.6830, longitude: 139.7597)),
            KilometerPoint(kilometer: 4, coordinate: CLLocationCoordinate2D(latitude: 35.6899, longitude: 139.7598)),
        ]
    }

    /// スタート地点
    static var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 35.6908, longitude: 139.7561)
    }

    /// ゴール地点
    static var goalCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 35.6899, longitude: 139.7598)
    }

    /// ルート中心点（カメラ用）
    static var routeCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 35.6840, longitude: 139.7530)
    }

    /// ペース範囲（グラデーション用）
    static var paceRange: (fast: TimeInterval, slow: TimeInterval) {
        (300, 360) // 5:00 〜 6:00
    }

    // MARK: - 年詳細用（年間のラン記録）

    static var yearDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now) // 今年のデータ（1〜8月）

        var records: [RunningRecord] = []

        // 各月に5〜8回のランを配置（1〜8月）
        for month in 1...8 {
            let runsInMonth = Int.random(in: 5...8)
            let daysUsed = Set((1...28).shuffled().prefix(runsInMonth))

            for day in daysUsed {
                var dateComponents = DateComponents()
                dateComponents.year = currentYear
                dateComponents.month = month
                dateComponents.day = day
                dateComponents.hour = Int.random(in: 6...9)

                guard let date = calendar.date(from: dateComponents) else { continue }

                let distance = Double.random(in: 3000...12000)
                records.append(RunningRecord(
                    id: UUID(),
                    date: date,
                    distanceInMeters: distance,
                    durationInSeconds: distance / 1000 * Double.random(in: 300...400),
                    caloriesBurned: distance / 15,
                    averageHeartRate: Double.random(in: 140...160),
                    maxHeartRate: Double.random(in: 165...180),
                    minHeartRate: Double.random(in: 120...140)
                ))
            }
        }

        return records.sorted { $0.date < $1.date }
    }

    /// 前年のラン記録（今年より若干少ない総距離）
    static var previousYearDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        let previousYear = calendar.component(.year, from: now) - 1

        var records: [RunningRecord] = []

        // 各月に4〜6回のランを配置（12ヶ月分、今年より少なめ）
        for month in 1...12 {
            let runsInMonth = Int.random(in: 4...6)
            let daysUsed = Set((1...28).shuffled().prefix(runsInMonth))

            for day in daysUsed {
                var dateComponents = DateComponents()
                dateComponents.year = previousYear
                dateComponents.month = month
                dateComponents.day = day
                dateComponents.hour = Int.random(in: 6...9)

                guard let date = calendar.date(from: dateComponents) else { continue }

                // 今年より若干短い距離
                let distance = Double.random(in: 2500...10000)
                records.append(RunningRecord(
                    id: UUID(),
                    date: date,
                    distanceInMeters: distance,
                    durationInSeconds: distance / 1000 * Double.random(in: 300...400),
                    caloriesBurned: distance / 15,
                    averageHeartRate: Double.random(in: 140...160),
                    maxHeartRate: Double.random(in: 165...180),
                    minHeartRate: Double.random(in: 120...140)
                ))
            }
        }

        return records.sorted { $0.date < $1.date }
    }

    // MARK: - 月詳細用

    static var monthDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // 今月のデータを使用（20日まで）
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        let baseDate = calendar.date(from: components)!

        // 今月の様々な日にデータを配置（10件）- 20日まで
        let daysWithRuns = [20, 18, 15, 12, 10, 8, 5, 3, 2, 1]

        return daysWithRuns.enumerated().map { index, day in
            var dateComponents = DateComponents()
            dateComponents.year = currentYear
            dateComponents.month = currentMonth
            dateComponents.day = day
            dateComponents.hour = Int.random(in: 6...9) // 朝ラン
            let date = calendar.date(from: dateComponents) ?? baseDate

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
