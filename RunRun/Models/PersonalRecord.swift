import Foundation

struct PersonalRecord: Identifiable, Equatable {
    let id = UUID()
    let distanceType: DistanceType
    let record: RunningRecord?

    enum DistanceType: String, CaseIterable {
        case fiveK = "5km"
        case tenK = "10km"
        case halfMarathon = "Half"
        case marathon = "Full"

        var range: ClosedRange<Double> {
            switch self {
            case .fiveK: return 4.8...5.2
            case .tenK: return 9.5...10.5
            case .halfMarathon: return 20.5...21.7
            case .marathon: return 41.5...43.0
            }
        }

        var displayName: String {
            switch self {
            case .fiveK: return String(localized: "PR_5km", comment: "Personal record distance type")
            case .tenK: return String(localized: "PR_10km", comment: "Personal record distance type")
            case .halfMarathon: return String(localized: "PR_Half", comment: "Personal record distance type - Half Marathon")
            case .marathon: return String(localized: "PR_Full", comment: "Personal record distance type - Full Marathon")
            }
        }
    }

    static func == (lhs: PersonalRecord, rhs: PersonalRecord) -> Bool {
        lhs.distanceType == rhs.distanceType && lhs.record?.id == rhs.record?.id
    }
}
