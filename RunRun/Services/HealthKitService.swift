import Foundation
import HealthKit
import CoreLocation

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "HealthKit is not available on this device")
        case .authorizationDenied:
            return String(localized: "Health data access is not authorized")
        case .queryFailed(let error):
            return String(localized: "Failed to fetch data") + ": \(error.localizedDescription)"
        }
    }
}

final class HealthKitService: Sendable {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Background Delivery

    /// バックグラウンド配信を有効化（ワークアウト変更時にアプリを起動）
    func enableBackgroundDelivery() async throws {
        guard isAvailable else { return }
        let workoutType = HKObjectType.workoutType()
        try await healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate)
    }

    /// ワークアウトの変更を監視
    func startObservingWorkouts(onUpdate: @escaping @Sendable () -> Void) {
        guard isAvailable else { return }
        let workoutType = HKObjectType.workoutType()

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            if error == nil {
                onUpdate()
            }
            completionHandler()
        }

        healthStore.execute(query)
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .runningStrideLength)!,
            HKSeriesType.workoutRoute()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    func fetchRunningWorkouts(from startDate: Date, to endDate: Date) async throws -> [RunningRecord] {
        let workoutType = HKObjectType.workoutType()

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let compoundPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [datePredicate, runningPredicate]
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let records = (samples as? [HKWorkout])?.map { workout in
                    RunningRecord(
                        id: UUID(),
                        date: workout.startDate,
                        distanceInMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                        durationInSeconds: workout.duration,
                        caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    )
                } ?? []

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    func fetchAllRunningWorkouts() async throws -> [RunningRecord] {
        let workouts = try await fetchAllRawRunningWorkouts()
        return workouts.map { workout in
            RunningRecord(
                id: UUID(),
                date: workout.startDate,
                distanceInMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                durationInSeconds: workout.duration,
                caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            )
        }
    }

    /// 生のHKWorkoutオブジェクトを取得（詳細データ取得用）
    func fetchAllRawRunningWorkouts() async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: runningPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    /// HKWorkoutからRunningRecordを作成（詳細データ付き）
    func createRunningRecord(from workout: HKWorkout, withDetails: Bool = false) async -> RunningRecord {
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())

        if withDetails {
            let details = await fetchWorkoutDetails(for: workout)
            return RunningRecord(
                id: UUID(),
                date: workout.startDate,
                distanceInMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                durationInSeconds: workout.duration,
                caloriesBurned: calories,
                averageHeartRate: details.averageHeartRate,
                maxHeartRate: details.maxHeartRate,
                minHeartRate: details.minHeartRate,
                cadence: details.cadence,
                strideLength: details.strideLength,
                stepCount: details.stepCount
            )
        } else {
            return RunningRecord(
                id: UUID(),
                date: workout.startDate,
                distanceInMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                durationInSeconds: workout.duration,
                caloriesBurned: calories
            )
        }
    }

    /// ワークアウトの詳細統計を取得
    func fetchWorkoutDetails(for workout: HKWorkout) async -> (
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        minHeartRate: Double?,
        stepCount: Int?,
        strideLength: Double?,
        cadence: Double?
    ) {
        async let heartRateStats = fetchHeartRateStats(for: workout)
        async let stepStats = fetchStepCount(for: workout)
        async let strideStats = fetchStrideLength(for: workout)

        let hr = await heartRateStats
        let steps = await stepStats
        let stride = await strideStats

        // ケイデンス計算: 歩数 / 時間（分）
        var cadence: Double? = nil
        if let steps = steps, workout.duration > 0 {
            cadence = Double(steps) / (workout.duration / 60.0)
        }

        return (hr.average, hr.max, hr.min, steps, stride, cadence)
    }

    private func fetchHeartRateStats(for workout: HKWorkout) async -> (average: Double?, max: Double?, min: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax, .discreteMin]
            ) { _, statistics, _ in
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                let average = statistics?.averageQuantity()?.doubleValue(for: bpmUnit)
                let max = statistics?.maximumQuantity()?.doubleValue(for: bpmUnit)
                let min = statistics?.minimumQuantity()?.doubleValue(for: bpmUnit)
                continuation.resume(returning: (average, max, min))
            }
            healthStore.execute(query)
        }
    }

    /// ワークアウト中の心拍数サンプルを時系列で取得
    func fetchHeartRateSamples(for workout: HKWorkout) async -> [HeartRateSample] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                let workoutStart = workout.startDate

                let hrSamples = samples.map { sample in
                    var hrSample = HeartRateSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: bpmUnit)
                    )
                    hrSample.elapsedSeconds = sample.startDate.timeIntervalSince(workoutStart)
                    return hrSample
                }

                continuation.resume(returning: hrSamples)
            }
            healthStore.execute(query)
        }
    }

    /// 指定した時間範囲の心拍数統計を計算
    func calculateHeartRateStats(
        samples: [HeartRateSample],
        from startTime: Date,
        to endTime: Date
    ) -> (avg: Double?, max: Double?, min: Double?) {
        let filteredSamples = samples.filter {
            $0.timestamp >= startTime && $0.timestamp <= endTime
        }

        guard !filteredSamples.isEmpty else { return (nil, nil, nil) }

        let bpms = filteredSamples.map { $0.bpm }
        let avg = bpms.reduce(0, +) / Double(bpms.count)
        let max = bpms.max()
        let min = bpms.min()

        return (avg, max, min)
    }

    private func fetchStepCount(for workout: HKWorkout) async -> Int? {
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0) })
            }
            healthStore.execute(query)
        }
    }

    private func fetchStrideLength(for workout: HKWorkout) async -> Double? {
        let strideType = HKQuantityType(.runningStrideLength)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: strideType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let stride = statistics?.averageQuantity()?.doubleValue(for: .meter())
                continuation.resume(returning: stride)
            }
            healthStore.execute(query)
        }
    }

    func fetchMonthlyStats(for year: Int) async throws -> [MonthlyRunningStats] {
        var stats: [MonthlyRunningStats] = []
        let calendar = Calendar.current

        for month in 1...12 {
            guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
                continue
            }

            // Skip future months
            if startDate > Date() {
                continue
            }

            let records = try await fetchRunningWorkouts(from: startDate, to: endDate)

            let totalDistance = records.reduce(0) { $0 + $1.distanceInMeters }
            let totalDuration = records.reduce(0) { $0 + $1.durationInSeconds }
            let totalCalories = records.compactMap { $0.caloriesBurned }.reduce(0, +)

            stats.append(MonthlyRunningStats(
                id: UUID(),
                year: year,
                month: month,
                totalDistanceInMeters: totalDistance,
                totalDurationInSeconds: totalDuration,
                runCount: records.count,
                totalCalories: totalCalories
            ))
        }

        return stats
    }

    // MARK: - Route Data

    /// ワークアウトのGPSルートを取得
    func fetchWorkoutRoute(for workout: HKWorkout) async -> [CLLocation] {
        // まずワークアウトに紐づくルートを取得
        let routes = await fetchRouteObjects(for: workout)
        guard let route = routes.first else { return [] }

        // ルートからロケーションデータを取得
        return await fetchLocations(from: route)
    }

    private func fetchRouteObjects(for workout: HKWorkout) async -> [HKWorkoutRoute] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let routes = (samples as? [HKWorkoutRoute]) ?? []
                continuation.resume(returning: routes)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLocations(from route: HKWorkoutRoute) async -> [CLLocation] {
        return await withCheckedContinuation { continuation in
            var allLocations: [CLLocation] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations = locations {
                    allLocations.append(contentsOf: locations)
                }
                if done {
                    continuation.resume(returning: allLocations)
                }
            }
            healthStore.execute(query)
        }
    }

    /// GPSロケーションからスプリット（単位ごとのペース）を計算
    /// - キロメートル表示: 1km間隔
    /// - マイル表示: 1マイル間隔
    func calculateSplits(from locations: [CLLocation]) -> [Split] {
        guard locations.count >= 2 else { return [] }

        // 単位に応じてスプリット間隔を決定（1km or 1mi）
        let splitInterval: Double = DistanceUnit.current == .miles ? 1609.34 : 1000.0
        let minFraction: Double = DistanceUnit.current == .miles ? 160.0 : 100.0

        var splits: [Split] = []
        var currentSegment = 1
        var segmentStartIndex = 0
        var accumulatedDistance: Double = 0

        for i in 1..<locations.count {
            let distance = locations[i].distance(from: locations[i - 1])
            accumulatedDistance += distance

            // スプリット間隔到達
            if accumulatedDistance >= splitInterval {
                let startTime = locations[segmentStartIndex].timestamp
                let endTime = locations[i].timestamp
                let duration = endTime.timeIntervalSince(startTime)

                splits.append(Split(
                    kilometer: currentSegment,
                    durationSeconds: duration,
                    distanceMeters: accumulatedDistance,
                    startTime: startTime,
                    endTime: endTime
                ))

                currentSegment += 1
                segmentStartIndex = i
                accumulatedDistance = 0
            }
        }

        // 最後の端数を追加
        if accumulatedDistance > minFraction && segmentStartIndex < locations.count - 1 {
            let startTime = locations[segmentStartIndex].timestamp
            let endTime = locations[locations.count - 1].timestamp
            let duration = endTime.timeIntervalSince(startTime)

            splits.append(Split(
                kilometer: currentSegment,
                durationSeconds: duration,
                distanceMeters: accumulatedDistance,
                startTime: startTime,
                endTime: endTime
            ))
        }

        return splits
    }

    /// スプリットに心拍数データを付加
    func enrichSplitsWithHeartRate(
        splits: [Split],
        heartRateSamples: [HeartRateSample]
    ) -> [Split] {
        return splits.map { split in
            var enrichedSplit = split

            if let start = split.startTime, let end = split.endTime {
                let stats = calculateHeartRateStats(
                    samples: heartRateSamples,
                    from: start,
                    to: end
                )
                enrichedSplit.averageHeartRate = stats.avg
                enrichedSplit.maxHeartRate = stats.max
                enrichedSplit.minHeartRate = stats.min
            }

            return enrichedSplit
        }
    }

    // MARK: - Route Segments

    /// GPSロケーションからペース別にセグメント分割
    func calculateRouteSegments(
        from locations: [CLLocation],
        segmentDistance: Double = 100
    ) -> [RouteSegment] {
        guard locations.count >= 2 else { return [] }

        var segments: [RouteSegment] = []
        var currentSegmentCoords: [CLLocationCoordinate2D] = [locations[0].coordinate]
        var segmentStartIndex = 0
        var accumulatedDistance: Double = 0

        for i in 1..<locations.count {
            let distance = locations[i].distance(from: locations[i - 1])
            accumulatedDistance += distance
            currentSegmentCoords.append(locations[i].coordinate)

            if accumulatedDistance >= segmentDistance {
                let startTime = locations[segmentStartIndex].timestamp
                let endTime = locations[i].timestamp
                let duration = endTime.timeIntervalSince(startTime)

                // ペース（秒/km）を計算
                let pacePerKm = duration / (accumulatedDistance / 1000)

                segments.append(RouteSegment(
                    coordinates: currentSegmentCoords,
                    pacePerKm: pacePerKm
                ))

                // 新しいセグメント開始（最後の点を含めて連続性を保つ）
                currentSegmentCoords = [locations[i].coordinate]
                segmentStartIndex = i
                accumulatedDistance = 0
            }
        }

        // 最後のセグメントを追加（セグメント距離の半分以上あれば追加）
        if accumulatedDistance > segmentDistance / 2 && currentSegmentCoords.count >= 2 {
            let startTime = locations[segmentStartIndex].timestamp
            let endTime = locations[locations.count - 1].timestamp
            let duration = endTime.timeIntervalSince(startTime)
            let pacePerKm = duration / (accumulatedDistance / 1000)

            segments.append(RouteSegment(
                coordinates: currentSegmentCoords,
                pacePerKm: pacePerKm
            ))
        }

        return segments
    }
}
