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
            displayName: isEnglish ? "runrun_john" : "runrun_taro",
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
            TimelineRun(id: "run-1", date: now.addingTimeInterval(-1800), distanceKm: 5.23, durationSeconds: 1650, userId: "user-1", displayName: name("朝ラン派", "morning_miles"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 320, averageHeartRate: 152),
            TimelineRun(id: "run-2", date: now.addingTimeInterval(-5400), distanceKm: 10.5, durationSeconds: 3300, userId: "user-2", displayName: name("hana_5km", "sarahw_runs"), avatarURL: nil, iconName: "hare.fill", caloriesBurned: 650, averageHeartRate: 145),
            TimelineRun(id: "run-3", date: now.addingTimeInterval(-10800), distanceKm: 7.8, durationSeconds: 2700, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 480, averageHeartRate: 148),
            // 昨日
            TimelineRun(id: "run-4", date: now.addingTimeInterval(-86400 - 3600), distanceKm: 3.2, durationSeconds: 1080, userId: "user-3", displayName: name("皇居ランナー", "trail_dave"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 195, averageHeartRate: 138),
            TimelineRun(id: "run-5", date: now.addingTimeInterval(-86400 - 10800), distanceKm: 8.1, durationSeconds: 2580, userId: "user-4", displayName: name("あいらん🏃‍♀️", "em_runner"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 510, averageHeartRate: 155),
            TimelineRun(id: "run-6", date: now.addingTimeInterval(-86400 - 18000), distanceKm: 6.5, durationSeconds: 2100, userId: "user-5", displayName: name("sho_sub3.5", "chris42k"), avatarURL: nil, iconName: "flame.fill", caloriesBurned: 410, averageHeartRate: 148),
            // 2日前
            TimelineRun(id: "run-7", date: now.addingTimeInterval(-172800 - 7200), distanceKm: 12.3, durationSeconds: 4020, userId: "user-6", displayName: name("週末10k", "jess_jogs"), avatarURL: nil, iconName: "star.fill", caloriesBurned: 780, averageHeartRate: 142),
            TimelineRun(id: "run-8", date: now.addingTimeInterval(-172800 - 14400), distanceKm: 4.8, durationSeconds: 1560, userId: "user-7", displayName: name("takuya1985", "ry_runs"), avatarURL: nil, iconName: "mountain.2.fill", caloriesBurned: 300, averageHeartRate: 140),
            TimelineRun(id: "run-9", date: now.addingTimeInterval(-172800 - 21600), distanceKm: 9.2, durationSeconds: 2940, userId: "user-8", displayName: name("miho_jogger", "mandy_pace"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 580, averageHeartRate: 150),
            // 3日前
            TimelineRun(id: "run-10", date: now.addingTimeInterval(-259200 - 3600), distanceKm: 5.5, durationSeconds: 1800, userId: "user-9", displayName: name("k.morita", "kev_strava"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 345, averageHeartRate: 144),
            TimelineRun(id: "run-11", date: now.addingTimeInterval(-259200 - 10800), distanceKm: 7.0, durationSeconds: 2310, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 440, averageHeartRate: 146),
            TimelineRun(id: "run-12", date: now.addingTimeInterval(-259200 - 18000), distanceKm: 4.2, durationSeconds: 1380, userId: "user-10", displayName: name("さおりんご", "lmartinez"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 265, averageHeartRate: 138),
            // 4日前
            TimelineRun(id: "run-13", date: now.addingTimeInterval(-345600 - 7200), distanceKm: 15.0, durationSeconds: 4800, userId: "user-11", displayName: name("daichi_ultra", "danny_5am"), avatarURL: nil, iconName: "hare.fill", caloriesBurned: 950, averageHeartRate: 152),
            TimelineRun(id: "run-14", date: now.addingTimeInterval(-345600 - 14400), distanceKm: 6.8, durationSeconds: 2200, userId: "user-12", displayName: name("rie_yoga_run", "rlee_nyc"), avatarURL: nil, iconName: "star.fill", caloriesBurned: 425, averageHeartRate: 142),
            // 5日前
            TimelineRun(id: "run-15", date: now.addingTimeInterval(-432000 - 3600), distanceKm: 8.5, durationSeconds: 2720, userId: "user-13", displayName: name("しみしみ", "b.clark"), avatarURL: nil, iconName: "flame.fill", caloriesBurned: 535, averageHeartRate: 148),
            TimelineRun(id: "run-16", date: now.addingTimeInterval(-432000 - 10800), distanceKm: 5.0, durationSeconds: 1650, userId: "user-14", displayName: name("yumi_slow", "meg_w"), avatarURL: nil, iconName: "figure.run", caloriesBurned: 315, averageHeartRate: 140),
            TimelineRun(id: "run-17", date: now.addingTimeInterval(-432000 - 18000), distanceKm: 11.2, durationSeconds: 3640, userId: currentUserId, displayName: currentUser.displayName, avatarURL: nil, iconName: "figure.run", caloriesBurned: 705, averageHeartRate: 150),
            // 6日前
            TimelineRun(id: "run-18", date: now.addingTimeInterval(-518400 - 7200), distanceKm: 3.8, durationSeconds: 1260, userId: "user-15", displayName: name("おかけん", "justinH_"), avatarURL: nil, iconName: "bolt.fill", caloriesBurned: 240, averageHeartRate: 136),
            TimelineRun(id: "run-19", date: now.addingTimeInterval(-518400 - 14400), distanceKm: 7.5, durationSeconds: 2475, userId: "user-16", displayName: name("akari_3776", "nikki.r"), avatarURL: nil, iconName: "heart.fill", caloriesBurned: 470, averageHeartRate: 144),
            // 7日前
            TimelineRun(id: "run-20", date: now.addingTimeInterval(-604800 - 3600), distanceKm: 6.2, durationSeconds: 2046, userId: "user-17", displayName: name("seiji_run", "drewruns"), avatarURL: nil, iconName: "mountain.2.fill", caloriesBurned: 390, averageHeartRate: 142),
        ]
    }

    // MARK: - 月間記録用

    /// 月別統計（yearDetailRecordsと整合性を保つ固定値）
    /// 人間らしいサボり期間あり:
    /// - 2月: 仕事が忙しくて2回だけ（15km）
    /// - 6月: 膝を痛めてほぼ休み（12km）
    /// 合計440km（前年8月末400kmの10%増）
    static var monthlyStats: [MonthlyRunningStats] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // 月ごとの固定データ（距離m, 回数）- yearDetailRecordsと一致
        let monthlyData: [(distance: Double, runCount: Int)] = [
            (65000, 8),   // 1月: 65km - 新年のやる気
            (15000, 2),   // 2月: 15km - 繁忙期で2回だけ
            (60000, 7),   // 3月: 60km - 暖かくなって復活
            (72000, 9),   // 4月: 72km - 絶好調
            (78000, 10),  // 5月: 78km - ベストシーズン
            (12000, 2),   // 6月: 12km - 膝痛めてほぼ休み
            (58000, 7),   // 7月: 58km - リハビリ兼ねて再開
            (80000, 9),   // 8月: 80km - 夏休みで追い込み
            (0, 0),       // 9月: データなし
            (0, 0),       // 10月
            (0, 0),       // 11月
            (0, 0),       // 12月
        ]

        return (1...12).map { month in
            let data = monthlyData[month - 1]
            return MonthlyRunningStats(
                id: UUID(),
                year: currentYear,
                month: month,
                totalDistanceInMeters: data.distance,
                totalDurationInSeconds: data.distance / 1000 * 330,
                runCount: data.runCount,
                totalCalories: data.distance / 1000 * 60
            )
        }
    }

    // MARK: - ランキング用（20件）

    static var leaderboardUsers: [UserProfile] {
        [
            UserProfile(id: "leader-1", displayName: name("毎日5k", "jw_marathon"), email: nil, iconName: "hare.fill", totalDistanceKm: 245.8, totalRuns: 42),
            UserProfile(id: "leader-2", displayName: name("sakura_pb更新中", "emma.t"), email: nil, iconName: "flame.fill", totalDistanceKm: 228.3, totalRuns: 38),
            UserProfile(id: "leader-3", displayName: name("kenta_箱根", "mike_b_runs"), email: nil, iconName: "bolt.fill", totalDistanceKm: 215.6, totalRuns: 36),
            UserProfile(id: "leader-4", displayName: name("miporin", "liv.runs"), email: nil, iconName: "star.fill", totalDistanceKm: 198.2, totalRuns: 34),
            UserProfile(id: "leader-5", displayName: name("dice_run", "will_j"), email: nil, iconName: "figure.run", totalDistanceKm: 185.3, totalRuns: 32),
            UserProfile(id: currentUserId, displayName: currentUser.displayName, email: nil, iconName: "figure.run", totalDistanceKm: 156.8, totalRuns: 28),
            UserProfile(id: "leader-7", displayName: name("shota_ito", "alex.m"), email: nil, iconName: "heart.fill", totalDistanceKm: 148.5, totalRuns: 26),
            UserProfile(id: "leader-8", displayName: name("ai_watanabe", "sophieg"), email: nil, iconName: "flame.fill", totalDistanceKm: 142.1, totalRuns: 24),
            UserProfile(id: "leader-9", displayName: name("makoto_k", "ben_mtz"), email: nil, iconName: "hare.fill", totalDistanceKm: 135.7, totalRuns: 23),
            UserProfile(id: "leader-10", displayName: name("yuuumi", "bella_runs"), email: nil, iconName: "star.fill", totalDistanceKm: 128.5, totalRuns: 22),
            UserProfile(id: "leader-11", displayName: name("t.yoshida", "ethan.t"), email: nil, iconName: "mountain.2.fill", totalDistanceKm: 121.3, totalRuns: 21),
            UserProfile(id: "leader-12", displayName: name("keikoy", "charlie_t"), email: nil, iconName: "bolt.fill", totalDistanceKm: 115.2, totalRuns: 20),
            UserProfile(id: "leader-13", displayName: name("taku.m", "mason_m"), email: nil, iconName: "figure.run", totalDistanceKm: 108.8, totalRuns: 19),
            UserProfile(id: "leader-14", displayName: name("saori_i", "amelia.j"), email: nil, iconName: "heart.fill", totalDistanceKm: 102.4, totalRuns: 18),
            UserProfile(id: "leader-15", displayName: name("kohei_k", "lucas.w"), email: nil, iconName: "flame.fill", totalDistanceKm: 96.1, totalRuns: 17),
            UserProfile(id: "leader-16", displayName: name("akr_saitou", "harper_h"), email: nil, iconName: "hare.fill", totalDistanceKm: 89.7, totalRuns: 16),
            UserProfile(id: "leader-17", displayName: name("d_shimizu", "noah.m"), email: nil, iconName: "star.fill", totalDistanceKm: 83.4, totalRuns: 15),
            UserProfile(id: "leader-18", displayName: name("rie_morita", "evelyn_t"), email: nil, iconName: "mountain.2.fill", totalDistanceKm: 77.2, totalRuns: 14),
            UserProfile(id: "leader-19", displayName: name("fujii_k1", "liam.r"), email: nil, iconName: "bolt.fill", totalDistanceKm: 71.0, totalRuns: 13),
            UserProfile(id: "leader-20", displayName: name("misaki_n", "ava.c"), email: nil, iconName: "figure.run", totalDistanceKm: 65.3, totalRuns: 12),
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

    /// 今年のラン記録（1〜8月）
    /// 8月末時点で前年8月末の約10%増（440km vs 400km）
    /// 人間らしいサボり期間:
    /// - 2月: 繁忙期で2回だけ（15km）
    /// - 6月: 膝痛めてほぼ休み（12km）
    static var yearDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        let monthlyData: [(month: Int, runs: [(day: Int, distance: Double)])] = [
            // 1月: 65km (8回) - 新年のやる気、週末に固め打ち
            (1, [(1, 10200), (2, 8500), (3, 5300), (11, 6800), (12, 9200), (18, 12500), (25, 5200), (26, 7300)]),
            // 2月: 15km (2回) - 繁忙期、月末にやっと2回だけ
            (2, [(23, 7200), (24, 7800)]),
            // 3月: 60km (7回) - 暖かくなって復活、週末中心
            (3, [(1, 5800), (2, 8200), (9, 10500), (16, 6200), (22, 9800), (23, 12300), (30, 7200)]),
            // 4月: 72km (9回) - 絶好調、GW前に追い込み
            (4, [(5, 6500), (6, 9200), (12, 10800), (13, 5200), (20, 8500), (26, 7800), (27, 11200), (29, 6300), (30, 6500)]),
            // 5月: 78km (10回) - ベストシーズン、GW連休で走り込み
            (5, [(3, 10500), (4, 8200), (5, 6800), (6, 5500), (11, 9200), (18, 7500), (19, 10800), (25, 6200), (26, 8100), (31, 5200)]),
            // 6月: 12km (2回) - 膝を痛めて月初で離脱、月末に恐る恐る再開
            (6, [(1, 5800), (29, 6200)]),
            // 7月: 58km (7回) - リハビリ、様子見ながら週末だけ
            (7, [(6, 5200), (7, 6800), (14, 8500), (20, 9200), (21, 10500), (27, 8300), (28, 9500)]),
            // 8月: 80km (9回) - 完全復活、お盆休みで追い込み
            (8, [(3, 6800), (4, 8500), (10, 12100), (11, 9200), (12, 7500), (17, 10800), (18, 8200), (24, 9500), (25, 7400)]),
        ]

        var records: [RunningRecord] = []
        for monthData in monthlyData {
            for run in monthData.runs {
                var dateComponents = DateComponents()
                dateComponents.year = currentYear
                dateComponents.month = monthData.month
                dateComponents.day = run.day
                dateComponents.hour = 7

                guard let date = calendar.date(from: dateComponents) else { continue }

                records.append(RunningRecord(
                    id: UUID(),
                    date: date,
                    distanceInMeters: run.distance,
                    durationInSeconds: run.distance / 1000 * 340,
                    caloriesBurned: run.distance / 15,
                    averageHeartRate: 150,
                    maxHeartRate: 168,
                    minHeartRate: 132
                ))
            }
        }

        return records.sorted { $0.date < $1.date }
    }

    /// 前年のラン記録（12ヶ月分）
    /// 8月末時点で400km、年間合計600km
    /// 人間らしいサボり期間:
    /// - 3月: インフルエンザで3回だけ（18km）
    /// - 7月: 家族旅行で3回だけ（22km）
    static var previousYearDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        let previousYear = calendar.component(.year, from: now) - 1

        let monthlyData: [(month: Int, runs: [(day: Int, distance: Double)])] = [
            // 1月: 55km (7回) - 正月休みに連日、その後週末
            (1, [(2, 8500), (3, 7200), (4, 6800), (13, 9200), (14, 8100), (27, 7500), (28, 7700)]),
            // 2月: 48km (6回) - 週末中心
            (2, [(4, 8200), (5, 7500), (11, 9100), (18, 6800), (25, 8200), (26, 8200)]),
            // 3月: 18km (3回) - インフルエンザで月半ば離脱
            (3, [(4, 6500), (5, 5800), (25, 5700)]),
            // 4月: 62km (8回) - 回復して頑張る、週末固め打ち
            (4, [(6, 7200), (7, 8500), (13, 6800), (14, 9500), (20, 7200), (21, 10200), (28, 6100), (29, 6500)]),
            // 5月: 70km (9回) - GW連休で走り込み
            (5, [(3, 8200), (4, 6500), (5, 9800), (6, 7200), (11, 8500), (12, 6800), (25, 10200), (26, 6300), (27, 6500)]),
            // 6月: 45km (6回) - 梅雨の晴れ間
            (6, [(1, 7500), (2, 8200), (15, 6800), (16, 9500), (29, 6200), (30, 6800)]),
            // 7月: 22km (3回) - 家族で2週間旅行
            (7, [(5, 8200), (6, 7500), (28, 6300)]),
            // 8月: 80km (10回) - 帰ってきてお盆休みに追い込み
            (8, [(3, 7200), (4, 8500), (10, 9200), (11, 6800), (12, 10200), (13, 7500), (17, 8800), (18, 7200), (24, 8100), (25, 6500)]),
            // 9月: 52km (7回) - 週末中心
            (9, [(7, 7500), (8, 8200), (14, 6500), (15, 9200), (22, 6800), (28, 7500), (29, 6300)]),
            // 10月: 60km (8回) - 秋のベストシーズン、連休活用
            (10, [(5, 8200), (6, 7500), (12, 6800), (13, 9500), (14, 7200), (26, 8500), (27, 6100), (28, 6200)]),
            // 11月: 50km (6回) - 週末のみ
            (11, [(2, 8500), (3, 9200), (16, 7200), (17, 8800), (23, 8100), (24, 8200)]),
            // 12月: 38km (5回) - 年末忙しい
            (12, [(7, 7500), (8, 8200), (14, 6800), (23, 8500), (30, 7000)]),
        ]

        var records: [RunningRecord] = []
        for monthData in monthlyData {
            for run in monthData.runs {
                var dateComponents = DateComponents()
                dateComponents.year = previousYear
                dateComponents.month = monthData.month
                dateComponents.day = run.day
                dateComponents.hour = 7

                guard let date = calendar.date(from: dateComponents) else { continue }

                records.append(RunningRecord(
                    id: UUID(),
                    date: date,
                    distanceInMeters: run.distance,
                    durationInSeconds: run.distance / 1000 * 350,
                    caloriesBurned: run.distance / 15,
                    averageHeartRate: 152,
                    maxHeartRate: 170,
                    minHeartRate: 135
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

        // 固定のシード値でランダムな距離を生成（スクショの一貫性のため）
        let distances = [8500.0, 5200.0, 10300.0, 6800.0, 7500.0, 4200.0, 9100.0, 5800.0, 6500.0, 7200.0]

        return daysWithRuns.enumerated().map { index, day in
            var dateComponents = DateComponents()
            dateComponents.year = currentYear
            dateComponents.month = currentMonth
            dateComponents.day = day
            dateComponents.hour = 7
            let date = calendar.date(from: dateComponents) ?? baseDate

            let distance = distances[index]
            return RunningRecord(
                id: UUID(),
                date: date,
                distanceInMeters: distance,
                durationInSeconds: distance / 1000 * 330,
                caloriesBurned: distance / 15,
                averageHeartRate: 148,
                maxHeartRate: 165,
                minHeartRate: 130
            )
        }
    }

    /// 前月の月詳細用
    /// - 20日時点での累積: 約67.5km（今月の71.1kmより約5%遅れ）
    /// - 月末までの合計: 約89.5km（今月20日時点より多い）
    static var previousMonthDetailRecords: [RunningRecord] {
        let calendar = Calendar.current
        let now = Date()
        var currentYear = calendar.component(.year, from: now)
        var currentMonth = calendar.component(.month, from: now)

        // 前月を計算
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }

        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        let baseDate = calendar.date(from: components)!

        // 前月のデータ（12件）
        // 1〜20日: 9件で合計67.5km（今月20日時点の71.1kmより約5%遅れ）
        // 21〜28日: 3件で追加22km → 月末合計89.5km
        // 今月と同様に起伏をつける（4km台〜10km台）
        let daysWithRuns = [1, 3, 6, 9, 11, 14, 16, 18, 20, 22, 25, 28]
        let distances = [10200.0, 4500.0, 8800.0, 5200.0, 9500.0, 4000.0, 8300.0, 6500.0, 10500.0, 8500.0, 4500.0, 9000.0]

        return daysWithRuns.enumerated().map { index, day in
            var dateComponents = DateComponents()
            dateComponents.year = currentYear
            dateComponents.month = currentMonth
            dateComponents.day = day
            dateComponents.hour = 7
            let date = calendar.date(from: dateComponents) ?? baseDate

            let distance = distances[index]
            return RunningRecord(
                id: UUID(),
                date: date,
                distanceInMeters: distance,
                durationInSeconds: distance / 1000 * 340,
                caloriesBurned: distance / 15,
                averageHeartRate: 150,
                maxHeartRate: 168,
                minHeartRate: 132
            )
        }
    }

    // MARK: - 目標用

    /// ユーザーの単位設定を取得
    private static var useMetric: Bool {
        UserDefaults.standard.object(forKey: "units.distance") as? Bool ?? UnitFormatter.defaultUseMetric
    }

    /// 年間目標（km: 500km, マイル: 300mi）
    static var yearlyGoal: RunningGoal {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        // マイル設定の場合は300マイル（約482.8km）、km設定の場合は500km
        let targetKm = useMetric ? 500.0 : 300.0 * 1.60934
        return RunningGoal(
            id: "mock-yearly-goal",
            type: .yearly,
            year: currentYear,
            month: nil,
            targetDistanceKm: targetKm,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// 月間目標（km: 100km, マイル: 60mi）
    static var monthlyGoal: RunningGoal {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        // マイル設定の場合は60マイル（約96.6km）、km設定の場合は100km
        let targetKm = useMetric ? 100.0 : 60.0 * 1.60934
        return RunningGoal(
            id: "mock-monthly-goal",
            type: .monthly,
            year: currentYear,
            month: currentMonth,
            targetDistanceKm: targetKm,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
