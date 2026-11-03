import Foundation
import FirebaseFirestore

/// 通報理由。rawValue は firestore.rules の reportReasons() と揃えること
enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriateName = "inappropriate_name"
    case inappropriatePhoto = "inappropriate_photo"
    case harassment
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriateName: return String(localized: "Inappropriate display name")
        case .inappropriatePhoto: return String(localized: "Inappropriate profile photo")
        case .harassment: return String(localized: "Harassment")
        case .spam: return String(localized: "Spam")
        case .other: return String(localized: "Other")
        }
    }
}

// MARK: - Reports

extension FirestoreService {
    /// 通報の詳細欄の最大文字数（Unicode スカラー単位）
    static let reportDetailsMaxLength = 500

    var reportsCollection: CollectionReference {
        db.collection("reports")
    }

    /// ユーザーを通報する。クライアントからは作成のみ可能で、確認と対応は運営が Firebase コンソールで行う
    func reportUser(reporterId: String, reportedUser: UserProfile, reason: ReportReason, details: String) async throws {
        guard let reportedUserId = reportedUser.id, reportedUserId != reporterId else { return }

        var data: [String: Any] = [
            "reporterId": reporterId,
            "reportedUserId": reportedUserId,
            // 通報時点の表示名を残す（後で変更されても確認できるように）
            "reportedDisplayName": String(reportedUser.displayName.unicodeScalars.prefix(100)),
            "reason": reason.rawValue,
            "status": "open",
            "createdAt": Date()
        ]

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDetails.isEmpty {
            data["details"] = String(trimmedDetails.unicodeScalars.prefix(Self.reportDetailsMaxLength))
        }

        _ = try await reportsCollection.addDocument(data: data)
    }
}
