import Foundation

struct RunningRecord: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date
    let distanceInMeters: Double
    let durationInSeconds: TimeInterval
    let caloriesBurned: Double?

    // 心拍数
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?

    // 効率指標
    var cadence: Double?        // 歩数/分
    var strideLength: Double?   // メートル
    var stepCount: Int?

    /// HealthKitデータからの初期化用
    init(
        id: UUID,
        date: Date,
        distanceInMeters: Double,
        durationInSeconds: TimeInterval,
        caloriesBurned: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        minHeartRate: Double? = nil,
        cadence: Double? = nil,
        strideLength: Double? = nil,
        stepCount: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.distanceInMeters = distanceInMeters
        self.durationInSeconds = durationInSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.cadence = cadence
        self.strideLength = strideLength
        self.stepCount = stepCount
    }

    /// Firestoreデータからの初期化用
    init(
        date: Date,
        distanceKm: Double,
        durationSeconds: TimeInterval,
        caloriesBurned: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        minHeartRate: Double? = nil,
        cadence: Double? = nil,
        strideLength: Double? = nil,
        stepCount: Int? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.distanceInMeters = distanceKm * 1000
        self.durationInSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.cadence = cadence
        self.strideLength = strideLength
        self.stepCount = stepCount
    }

    var distanceInKilometers: Double {
        distanceInMeters / 1000.0
    }

    var formattedDistance: String {
        String(format: "%.2f km", distanceInKilometers)
    }

    var formattedDuration: String {
        let hours = Int(durationInSeconds) / 3600
        let minutes = (Int(durationInSeconds) % 3600) / 60
        let seconds = Int(durationInSeconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var averagePacePerKilometer: TimeInterval? {
        guard distanceInKilometers > 0 else { return nil }
        return durationInSeconds / distanceInKilometers
    }

    var formattedPace: String {
        guard let pace = averagePacePerKilometer else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var formattedCalories: String? {
        guard let cal = caloriesBurned else { return nil }
        return String(format: "%.0f kcal", cal)
    }

    var formattedAverageHeartRate: String? {
        guard let hr = averageHeartRate else { return nil }
        return String(format: "%.0f bpm", hr)
    }

    var formattedMaxHeartRate: String? {
        guard let hr = maxHeartRate else { return nil }
        return String(format: "%.0f bpm", hr)
    }

    var formattedMinHeartRate: String? {
        guard let hr = minHeartRate else { return nil }
        return String(format: "%.0f bpm", hr)
    }

    var formattedCadence: String? {
        guard let cad = cadence else { return nil }
        return String(format: "%.0f spm", cad)
    }

    var formattedStrideLength: String? {
        guard let stride = strideLength else { return nil }
        return String(format: "%.2f m", stride)
    }

    var formattedStepCount: String? {
        guard let steps = stepCount else { return nil }
        return String(format: String(localized: "%d steps", comment: "Step count format"), steps)
    }
}
