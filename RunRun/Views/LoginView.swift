import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)

                Text("RunRun")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("ランニング記録を共有しよう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .frame(height: 50)
                .disabled(true)
                .opacity(0)
                .overlay {
                    Button {
                        signIn()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                                .allowsHitTesting(false)
                                .frame(height: 50)
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}
