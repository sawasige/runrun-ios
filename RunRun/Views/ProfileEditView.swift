import SwiftUI
import FirebaseAuth

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var selectedIcon: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let userId: String
    private let firestoreService = FirestoreService()

    init(userId: String, currentDisplayName: String, currentIcon: String) {
        self.userId = userId
        _displayName = State(initialValue: currentDisplayName)
        _selectedIcon = State(initialValue: currentIcon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("アイコン") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(UserProfile.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

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
                try await firestoreService.updateProfile(userId: userId, displayName: displayName, iconName: selectedIcon)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    ProfileEditView(userId: "test", currentDisplayName: "ランナー", currentIcon: "figure.run")
}
