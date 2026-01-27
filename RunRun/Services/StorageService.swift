import Foundation
import FirebaseStorage
import UIKit

final class StorageService {
    private let storage = Storage.storage()

    private func avatarRef(for userId: String) -> StorageReference {
        storage.reference().child("avatars/\(userId).jpg")
    }

    func uploadAvatar(userId: String, image: UIImage) async throws -> URL {
        let resizedImage = resizeImage(image, maxSize: 512)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw StorageError.invalidImage
        }

        let ref = avatarRef(for: userId)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()

        return downloadURL
    }

    /// 画像を正方形にクロップしてリサイズ（中央切り抜き）
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        // cgImageのraw pixelサイズを使用（orientationは無視される）
        let cgWidth = CGFloat(cgImage.width)
        let cgHeight = CGFloat(cgImage.height)

        // 1. 中央から正方形にクロップ（raw pixel座標で）
        let minSide = min(cgWidth, cgHeight)
        let cropRect = CGRect(
            x: (cgWidth - minSide) / 2,
            y: (cgHeight - minSide) / 2,
            width: minSide,
            height: minSide
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)

        // 2. 指定サイズにリサイズ
        let targetSize = min(minSide, maxSize)
        let newSize = CGSize(width: targetSize, height: targetSize)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
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
            return String(localized: "Failed to convert image")
        }
    }
}
