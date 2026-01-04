import Foundation
import Combine
import AuthenticationServices
import FirebaseAuth
import CryptoKit

enum AuthError: LocalizedError {
    case signInFailed(Error)
    case noIdentityToken
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .signInFailed(let error):
            return "サインインに失敗しました: \(error.localizedDescription)"
        case .noIdentityToken:
            return "認証トークンの取得に失敗しました"
        case .invalidCredential:
            return "認証情報が無効です"
        }
    }
}

@MainActor
final class AuthenticationService: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isAuthenticated = false

    private var currentNonce: String?
    private lazy var firestoreService = FirestoreService.shared

    init() {
        self.user = Auth.auth().currentUser
        self.isAuthenticated = user != nil

        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let result = try await performSignIn(request: request)
        try await handleSignInResult(result)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private func performSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = SignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.performRequests()

            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private func handleSignInResult(_ result: ASAuthorization) async throws {
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.noIdentityToken
        }

        guard let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)

        // Create user profile if first time
        let userId = authResult.user.uid
        let existingProfile = try? await firestoreService.getUserProfile(userId: userId)
        if existingProfile == nil {
            let displayName = appleIDCredential.fullName?.givenName ?? "ランナー"
            try await firestoreService.createUserProfile(
                userId: userId,
                displayName: displayName,
                email: authResult.user.email
            )
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private class SignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: AuthError.signInFailed(error))
    }
}
