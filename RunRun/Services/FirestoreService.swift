import Foundation
import FirebaseFirestore
import FirebaseAuth

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    lazy var db: Firestore = Firestore.firestore()

    private init() {}

    var usersCollection: CollectionReference {
        db.collection("users")
    }

    var runsCollection: CollectionReference {
        db.collection("runs")
    }

    var friendRequestsCollection: CollectionReference {
        db.collection("friendRequests")
    }
}
