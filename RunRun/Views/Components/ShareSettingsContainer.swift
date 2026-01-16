import SwiftUI
import PhotosUI
import Photos

/// 共有設定画面の共通コンテナ
/// 写真選択、プレビュー、保存・シェア機能を提供
struct ShareSettingsContainer<OptionsView: View>: View {
    @Binding var isPresented: Bool
    let analyticsScreenName: String
    let optionsChangeId: AnyHashable
    let composeImage: (Data) async -> Data?
    let logSaveEvent: () -> Void
    let logShareEvent: () -> Void
    @ViewBuilder let optionsSection: () -> OptionsView

    // 写真選択
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    // プレビュー・保存・シェア
    @State private var previewImageData: Data?
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showPermissionDenied = false
    @State private var shareItem: URL?

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationTitle(String(localized: "Share Settings"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(item: $shareItem) { url in
                    ShareSheet(activityItems: [url])
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await loadSelectedPhoto(from: newItem) }
                }
                .onChange(of: optionsChangeId) { _, _ in
                    Task { await updatePreview() }
                }
                .alert(String(localized: "Saved"), isPresented: $showSaveSuccess) {
                    Button("OK") { isPresented = false }
                }
                .alert(String(localized: "Failed to Save"), isPresented: $showSaveError) {
                    Button("OK", role: .cancel) {}
                }
                .alert(String(localized: "Photo Access Required"), isPresented: $showPermissionDenied) {
                    Button(String(localized: "Open Settings")) {
                        PhotoLibraryService.openSettings()
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text("Please allow photo library access to save images.")
                }
                .analyticsScreen(analyticsScreenName)
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                previewSection
                photoPickerButton
                optionsSection()
            }
            .padding()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Close")) {
                isPresented = false
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            HStack(spacing: 20) {
                shareButton
                saveButton
            }
        }
    }

    private var shareButton: some View {
        Button {
            Task { await shareImage() }
        } label: {
            if isSharing {
                ProgressView()
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(photoData == nil || isSharing || isSaving)
    }

    private var saveButton: some View {
        Button {
            Task { await saveToPhotos() }
        } label: {
            if isSaving {
                ProgressView()
            } else {
                Image(systemName: "photo.badge.plus")
            }
        }
        .disabled(photoData == nil || isSaving || isSharing)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            if let previewData = previewImageData {
                HDRImageView(imageData: previewData)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                emptyPreview
            }
        }
    }

    private var emptyPreview: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(UIColor.secondarySystemBackground))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Please select a photo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - Photo Picker Button

    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(photoData == nil ? String(localized: "Select Photo") : String(localized: "Change Photo"), systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Actions

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                photoData = data
                await updatePreview()
            }
        } catch {
            print("Failed to load photo: \(error)")
        }
    }

    func updatePreview() async {
        guard let data = photoData else {
            previewImageData = nil
            return
        }
        previewImageData = await composeImage(data)
    }

    private func saveToPhotos() async {
        guard let data = previewImageData else { return }

        let authorized = await PhotoLibraryService.ensureAuthorization()
        guard authorized else {
            showPermissionDenied = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            logSaveEvent()
            showSaveSuccess = true
        } catch {
            print("Failed to save: \(error)")
            showSaveError = true
        }
    }

    private func shareImage() async {
        guard let data = previewImageData else { return }

        isSharing = true

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")

        do {
            try data.write(to: tempURL)
            await MainActor.run {
                shareItem = tempURL
                isSharing = false
            }
            logShareEvent()
        } catch {
            print("Failed to create temp file: \(error)")
            await MainActor.run {
                isSharing = false
            }
        }
    }
}

// MARK: - Option Row Helper

struct ShareOptionRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

// MARK: - Options Section Container

struct ShareOptionsSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data to Export")
                .font(.headline)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
