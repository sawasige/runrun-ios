import SwiftUI
import FirebaseAuth

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let userId: String
    private let firestoreService = FirestoreService()

    init(userId: String, currentDisplayName: String) {
        self.userId = userId
        _displayName = State(initialValue: currentDisplayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("表示名") {
                    TextField("表示名", text: $displayName)
                        .textContentType(.name)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(displayName.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await firestoreService.updateDisplayName(userId: userId, displayName: displayName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    ProfileEditView(userId: "test", currentDisplayName: "ランナー")
}
