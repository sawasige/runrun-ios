import Foundation
import FirebaseStorage
import UIKit

final class StorageService {
    private let storage = Storage.storage()

    private func avatarRef(for userId: String) -> StorageReference {
        storage.reference().child("avatars/\(userId).jpg")
    }

    func uploadAvatar(userId: String, image: UIImage) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.invalidImage
        }

        let ref = avatarRef(for: userId)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()

        return downloadURL
    }

    func deleteAvatar(userId: String) async throws {
        let ref = avatarRef(for: userId)
        try await ref.delete()
    }
}

enum StorageError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "画像の変換に失敗しました"
        }
    }
}
