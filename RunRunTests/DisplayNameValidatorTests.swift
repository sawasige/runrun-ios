import Testing
@testable import RunRun

struct DisplayNameValidatorTests {
    @Test func acceptsOrdinaryNames() throws {
        #expect(DisplayNameValidator.validationError(for: "Runner") == nil)
        #expect(DisplayNameValidator.validationError(for: "山田 太郎") == nil)
        #expect(DisplayNameValidator.validationError(for: "🏃‍♂️ Run") == nil)
        #expect(try DisplayNameValidator.validated("  Runner  ") == "Runner")
    }

    @Test func rejectsEmptyOrWhitespaceOnly() {
        #expect(DisplayNameValidator.validationError(for: "") == .empty)
        #expect(DisplayNameValidator.validationError(for: "   ") == .empty)
        #expect(DisplayNameValidator.validationError(for: "\n\t") == .empty)
        #expect(DisplayNameValidator.validationError(for: "\u{3000}") == .empty)
    }

    @Test func rejectsTooLong() {
        let twenty = String(repeating: "あ", count: 20)
        #expect(DisplayNameValidator.validationError(for: twenty) == nil)
        #expect(DisplayNameValidator.validationError(for: twenty + "あ") == .tooLong)
        // 前後の空白は数えない
        #expect(DisplayNameValidator.validationError(for: "  \(twenty)  ") == nil)
    }

    @Test func rejectsControlCharacters() {
        #expect(DisplayNameValidator.validationError(for: "Run\nner") == .invalidCharacters)
        #expect(DisplayNameValidator.validationError(for: "Run\tner") == .invalidCharacters)
        #expect(DisplayNameValidator.validationError(for: "Run\u{0}ner") == .invalidCharacters)
    }

    @Test func validatedThrows() {
        #expect(throws: DisplayNameValidator.ValidationError.tooLong) {
            try DisplayNameValidator.validated(String(repeating: "a", count: 21))
        }
    }

    @Test func sanitizesExternalNames() {
        #expect(DisplayNameValidator.sanitized(nil, fallback: "Runner") == "Runner")
        #expect(DisplayNameValidator.sanitized("   ", fallback: "Runner") == "Runner")
        #expect(DisplayNameValidator.sanitized("  Taro  ", fallback: "Runner") == "Taro")
        #expect(DisplayNameValidator.sanitized("Ta\nro", fallback: "Runner") == "Taro")
        #expect(DisplayNameValidator.sanitized(String(repeating: "a", count: 30), fallback: "Runner")
                == String(repeating: "a", count: 20))
        #expect(DisplayNameValidator.sanitized(String(repeating: "a", count: 19) + " b", fallback: "Runner")
                == String(repeating: "a", count: 19))
    }
}
