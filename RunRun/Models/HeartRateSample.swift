import Foundation

struct HeartRateSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bpm: Double
    var elapsedSeconds: TimeInterval = 0
}
