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

    // アスペクト比（写真未選択時のみ使用）
    @State private var selectedAspectRatio: ImageAspectRatio = .square
    @State private var displayedAspectRatio: ImageAspectRatio = .square  // 表示用（画像生成完了後に更新）

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
                if photoData == nil {
                    aspectRatioPicker
                }
                photoPickerSection
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
        .disabled(previewImageData == nil || isSharing || isSaving)
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
        .disabled(previewImageData == nil || isSaving || isSharing)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            if let previewData = previewImageData {
                if photoData == nil {
                    // グラデーション: 高さ固定、幅のみ変化
                    gradientPreviewContainer {
                        HDRImageView(imageData: previewData)
                            .aspectRatio(displayedAspectRatio.size, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // 写真: 従来通り1:1固定
                    HDRImageView(imageData: previewData)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                loadingPreview
            }
        }
        .task {
            // 初期表示時にグラデーションでプレビュー生成
            if previewImageData == nil {
                await updatePreview()
            }
        }
    }

    /// 高さ固定のコンテナ（幅のみアスペクト比に応じて変化）
    private func gradientPreviewContainer<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geometry in
            let height = geometry.size.width  // 正方形の高さを基準
            let width = height * displayedAspectRatio.size.width / displayedAspectRatio.size.height

            content()
                .frame(width: width, height: height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var loadingPreview: some View {
        GeometryReader { geometry in
            let height = geometry.size.width
            let width = height * displayedAspectRatio.size.width / displayedAspectRatio.size.height

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: width, height: height)
                .overlay {
                    ProgressView()
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var aspectRatioPicker: some View {
        Picker(selection: $selectedAspectRatio) {
            ForEach(ImageAspectRatio.allCases, id: \.self) { ratio in
                Text(ratio.rawValue).tag(ratio)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedAspectRatio) { _, _ in
            Task { await updatePreview() }
        }
    }

    // MARK: - Photo Picker Section

    private var photoPickerSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(photoData == nil ? String(localized: "Select Photo") : String(localized: "Change Photo"), systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if photoData != nil {
                Button(role: .destructive) {
                    photoData = nil
                    selectedPhotoItem = nil
                    Task { await updatePreview() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
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
        let data: Data
        let newAspectRatio = selectedAspectRatio
        if let photoData = photoData {
            data = photoData
        } else {
            // 写真未選択時はグラデーション背景を使用
            guard let gradientData = ImageComposer.createGradientImageData(aspectRatio: newAspectRatio) else {
                previewImageData = nil
                return
            }
            data = gradientData
        }
        let newPreview = await composeImage(data)
        // 画像とアスペクト比を同時に更新（1回の再描画で完了）
        previewImageData = newPreview
        displayedAspectRatio = newAspectRatio
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
