import Photos
import UIKit

enum PhotoLibraryAuthorizationStatus {
    case authorized
    case denied
    case notDetermined
}

struct PhotoLibraryService {
    static func checkAuthorizationStatus() -> PhotoLibraryAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static func requestAuthorization() async -> PhotoLibraryAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// 写真を保存する前に許可を確認・リクエストする
    /// - Returns: 許可されていればtrue、拒否されていればfalse
    static func ensureAuthorization() async -> Bool {
        let status = checkAuthorizationStatus()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let newStatus = await requestAuthorization()
            return newStatus == .authorized
        case .denied:
            return false
        }
    }
}
