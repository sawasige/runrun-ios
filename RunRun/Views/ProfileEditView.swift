import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var selectedIcon: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var currentAvatarURL: URL?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let userId: String
    private let originalAvatarURL: URL?
    private let firestoreService = FirestoreService.shared
    private let storageService = StorageService()

    init(userId: String, currentDisplayName: String, currentIcon: String, currentAvatarURL: URL?) {
        self.userId = userId
        self.originalAvatarURL = currentAvatarURL
        _displayName = State(initialValue: currentDisplayName)
        _selectedIcon = State(initialValue: currentIcon)
        _currentAvatarURL = State(initialValue: currentAvatarURL)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Photo") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            avatarPreview
                                .frame(width: 100, height: 100)

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text("Select Photo")
                            }

                            if avatarImage != nil || currentAvatarURL != nil {
                                Button("Remove Photo", role: .destructive) {
                                    avatarImage = nil
                                    currentAvatarURL = nil
                                    selectedPhoto = nil
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("Icon (shown when no photo)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(UserProfile.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.accentColor : Color.gray.opacity(0.2))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Display Name") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .analyticsScreen("ProfileEdit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(displayName.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarImage = avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else if let currentAvatarURL = currentAvatarURL {
            AsyncImage(url: currentAvatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .clipShape(Circle())
        } else {
            Image(systemName: selectedIcon)
                .font(.system(size: 40))
                .frame(width: 100, height: 100)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        do {
            var newAvatarURL: URL? = currentAvatarURL

            // 新しい画像がある場合はアップロード
            if let avatarImage = avatarImage {
                newAvatarURL = try await storageService.uploadAvatar(userId: userId, image: avatarImage)
            } else if originalAvatarURL != nil && currentAvatarURL == nil {
                // 元々画像があったが削除された場合
                try? await storageService.deleteAvatar(userId: userId)
                try? await firestoreService.clearAvatarURL(userId: userId)
                newAvatarURL = nil
            }

            try await firestoreService.updateProfile(
                userId: userId,
                displayName: displayName,
                iconName: selectedIcon,
                avatarURL: newAvatarURL
            )
            AnalyticsService.logEvent("update_profile", parameters: [
                "has_avatar": newAvatarURL != nil
            ])
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    ProfileEditView(userId: "test", currentDisplayName: "Runner", currentIcon: "figure.run", currentAvatarURL: nil)
}
