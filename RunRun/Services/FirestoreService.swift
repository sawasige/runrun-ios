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

/// ユーザープロフィールの短期メモリキャッシュ。
/// タイムラインのページング等で同じプロフィールを繰り返し読むのを防ぎ、Firestoreの読み取り回数を削減する。
actor ProfileCache {
    private var entries: [String: (profile: UserProfile, timestamp: Date)] = [:]
    private let ttl: TimeInterval = 600 // 10分

    func get(_ userId: String) -> UserProfile? {
        guard let entry = entries[userId] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            entries[userId] = nil
            return nil
        }
        return entry.profile
    }

    func set(_ profile: UserProfile, for userId: String) {
        entries[userId] = (profile, Date())
    }

    func invalidate(_ userId: String) {
        entries[userId] = nil
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    lazy var db: Firestore = Firestore.firestore()

    let profileCache = ProfileCache()

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
