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
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
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
