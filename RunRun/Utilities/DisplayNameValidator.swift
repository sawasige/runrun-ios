import Foundation

/// 表示名の正規化と検証。
/// 条件は firestore.rules の users ルール（validDisplayName）と揃えておくこと。
nonisolated enum DisplayNameValidator {
    /// 最大文字数（Unicode スカラー単位。ルール側の正規表現 {1,20} と同じ数え方）
    static let maxLength = 20

    enum ValidationError: LocalizedError, Equatable {
        case empty
        case tooLong
        case invalidCharacters

        var errorDescription: String? {
            switch self {
            case .empty:
                return String(localized: "Enter a display name.")
            case .tooLong:
                return String(localized: "Display name must be \(DisplayNameValidator.maxLength) characters or fewer.")
            case .invalidCharacters:
                return String(localized: "Display name can't contain line breaks or control characters.")
            }
        }
    }

    /// 前後の空白・改行を取り除く
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 正規化後の文字数（Unicode スカラー単位）
    static func length(of name: String) -> Int {
        normalized(name).unicodeScalars.count
    }

    /// 検証して問題があればエラーを返す。問題がなければ nil
    static func validationError(for name: String) -> ValidationError? {
        let normalized = normalized(name)
        if normalized.isEmpty {
            return .empty
        }
        if normalized.unicodeScalars.contains(where: isControl) {
            return .invalidCharacters
        }
        if normalized.unicodeScalars.count > maxLength {
            return .tooLong
        }
        return nil
    }

    /// 検証を通った正規化済みの表示名を返す。通らなければ throw
    static func validated(_ name: String) throws -> String {
        let normalized = normalized(name)
        if let error = validationError(for: normalized) {
            throw error
        }
        return normalized
    }

    /// サインイン時などに外部から渡された名前を、検証を通る形に整える。
    /// 空になる場合は fallback を返す
    static func sanitized(_ name: String?, fallback: String) -> String {
        guard let name else { return fallback }
        let withoutControls = String(String.UnicodeScalarView(
            normalized(name).unicodeScalars.filter { !isControl($0) }
        ))
        let truncated = String(String.UnicodeScalarView(
            withoutControls.unicodeScalars.prefix(maxLength)
        ))
        let result = normalized(truncated)
        return result.isEmpty ? fallback : result
    }

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.generalCategory == .control
    }
}
