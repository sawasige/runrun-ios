import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    if let email = authService.user?.email {
                        HStack {
                            Text("メール")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("サインアウト", role: .destructive) {
                        try? authService.signOut()
                    }
                }

                Section("ヘルスケア") {
                    Button("ヘルスケア設定を開く") {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
