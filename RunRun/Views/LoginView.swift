import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Staggered animation states
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showDescription = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .scaleEffect(showLogo ? 1 : 0.5)
                    .opacity(showLogo ? 1 : 0)

                Text("RunRun")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .scaleEffect(showTitle ? 1 : 0.8)
                    .opacity(showTitle ? 1 : 0)

                Text("Visualize your running journey")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 8)

                Text("Works with Apple Watch, Strava, Nike Run Club, Garmin, and more via Apple Health")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(showDescription ? 1 : 0)
                    .offset(y: showDescription ? 0 : 8)
            }

            Spacer()

            VStack(spacing: 16) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    signIn()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .allowsHitTesting(false)
                            .frame(height: 50)
                            .id(colorScheme)
                    }
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .analyticsScreen("Login")
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        let baseDelay = 0.15

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showLogo = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(baseDelay * 2)) {
            showTitle = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(baseDelay * 4)) {
            showTagline = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(baseDelay * 6)) {
            showDescription = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(baseDelay * 8)) {
            showButton = true
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
