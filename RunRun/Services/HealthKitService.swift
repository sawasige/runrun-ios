import Foundation
import HealthKit

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKitはこのデバイスで利用できません"
        case .authorizationDenied:
            return "ヘルスケアへのアクセスが許可されていません"
        case .queryFailed(let error):
            return "データの取得に失敗しました: \(error.localizedDescription)"
        }
    }
}

final class HealthKitService: Sendable {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
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

            stats.append(MonthlyRunningStats(
                id: UUID(),
                year: year,
                month: month,
                totalDistanceInMeters: totalDistance,
                totalDurationInSeconds: totalDuration,
                runCount: records.count
            ))
        }

        return stats
    }
}
