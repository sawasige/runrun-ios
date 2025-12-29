import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var isSyncing = false
    @State private var lastSyncMessage: String?

    private let firestoreService = FirestoreService()
    private let healthKitService = HealthKitService()

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

                Section("データ同期") {
                    Button {
                        syncData()
                    } label: {
                        HStack {
                            Text("クラウドに同期")
                            Spacer()    
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)

                    if let message = lastSyncMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    private func syncData() {
        guard let userId = authService.user?.uid else { return }

        isSyncing = true
        lastSyncMessage = nil

        Task {
            do {
                let calendar = Calendar.current
                let now = Date()
                let startOfYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))!

                let records = try await healthKitService.fetchRunningWorkouts(from: startOfYear, to: now)
                try await firestoreService.syncRunRecords(userId: userId, records: records)

                lastSyncMessage = "\(records.count)件の記録を同期しました"
            } catch {
                lastSyncMessage = "同期エラー: \(error.localizedDescription)"
            }

            isSyncing = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
