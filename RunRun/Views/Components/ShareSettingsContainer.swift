import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import AVKit
import UniformTypeIdentifiers

/// 動画背景サポートをオプトインで有効化するための設定
struct VideoShareSupport {
    /// 動画が選択された直後に呼ばれる。背景明度サンプルなどを行い、
    /// オーバーレイ生成クロージャを返す。
    let prepareOverlay: @Sendable (URL) async -> (@Sendable (CGSize) -> CGImage?)?
    let logSaveEvent: () -> Void
    let logShareEvent: () -> Void
}

/// PhotosPickerからオリジナル形式のまま動画を取得するためのTransferable
private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { item in
            SentTransferredFile(item.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("share-video-\(UUID().uuidString)")
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVideo(url: dest)
        }
    }
}

/// 共有設定画面の共通コンテナ
/// 写真選択、プレビュー、保存・シェア機能を提供
struct ShareSettingsContainer<OptionsView: View>: View {
    @Binding var isPresented: Bool
    let analyticsScreenName: String
    let optionsChangeId: AnyHashable
    let composeImage: (Data, Bool) async -> Data?  // (imageData, centered)
    let videoSupport: VideoShareSupport?
    let logSaveEvent: () -> Void
    let logShareEvent: () -> Void
    @ViewBuilder let optionsSection: () -> OptionsView

    init(
        isPresented: Binding<Bool>,
        analyticsScreenName: String,
        optionsChangeId: AnyHashable,
        composeImage: @escaping (Data, Bool) async -> Data?,
        videoSupport: VideoShareSupport? = nil,
        logSaveEvent: @escaping () -> Void,
        logShareEvent: @escaping () -> Void,
        @ViewBuilder optionsSection: @escaping () -> OptionsView
    ) {
        self._isPresented = isPresented
        self.analyticsScreenName = analyticsScreenName
        self.optionsChangeId = optionsChangeId
        self.composeImage = composeImage
        self.videoSupport = videoSupport
        self.logSaveEvent = logSaveEvent
        self.logShareEvent = logShareEvent
        self.optionsSection = optionsSection
    }

    // 写真/動画選択（背景）
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var videoURL: URL?
    @State private var videoOverlayBuilder: (@Sendable (CGSize) -> CGImage?)?
    @State private var videoPlayer: AVPlayer?

    // アスペクト比（背景未選択時のみ使用、保存される）
    @AppStorage("share.aspectRatio") private var selectedAspectRatio: ImageAspectRatio = .square
    @State private var displayedAspectRatio: ImageAspectRatio = .square  // 表示用（画像生成完了後に更新）

    // プレビュー・保存・シェア
    @State private var previewImageData: Data?
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var saveProgress: Float = 0  // 動画書き出し時の進捗
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
                .onChange(of: selectedPickerItem) { _, newItem in
                    Task { await loadSelectedMedia(from: newItem) }
                }
                .onChange(of: optionsChangeId) { _, _ in
                    Task { await rebuildAfterOptionsChange() }
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
                if photoData == nil && videoURL == nil {
                    aspectRatioPicker
                }
                backgroundPickerSection
                if isSaving && videoURL != nil {
                    VStack(spacing: 8) {
                        ProgressView(value: saveProgress)
                        Text(String(format: "%.0f%%", saveProgress * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
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
            Task { await shareTapped() }
        } label: {
            if isSharing {
                ProgressView()
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(!hasContent || isSharing || isSaving)
    }

    private var saveButton: some View {
        Button {
            Task { await saveTapped() }
        } label: {
            if isSaving {
                ProgressView()
            } else {
                Image(systemName: "photo.badge.plus")
            }
        }
        .disabled(!hasContent || isSaving || isSharing)
    }

    private var hasContent: Bool {
        previewImageData != nil || videoURL != nil
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            if let player = videoPlayer {
                // 動画プレビュー: AVPlayer + videoComposition でオーバーレイ反映
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else if let previewData = previewImageData {
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
            if previewImageData == nil && videoPlayer == nil {
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

    // MARK: - Background Picker Section

    private var backgroundPickerSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedPickerItem,
                matching: pickerFilter,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                Label(backgroundPickerLabel, systemImage: backgroundPickerIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if photoData != nil || videoURL != nil {
                Button(role: .destructive) {
                    clearBackground()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var pickerFilter: PHPickerFilter {
        videoSupport != nil ? .any(of: [.images, .videos]) : .images
    }

    private var backgroundPickerLabel: String {
        if videoURL != nil {
            return String(localized: "Change Background")
        }
        if photoData != nil {
            return String(localized: "Change Background")
        }
        return String(localized: "Select Background")
    }

    private var backgroundPickerIcon: String {
        if videoURL != nil { return "video" }
        return "photo"
    }

    private func clearBackground() {
        photoData = nil
        videoURL = nil
        videoOverlayBuilder = nil
        videoPlayer?.pause()
        videoPlayer = nil
        selectedPickerItem = nil
        Task { await updatePreview() }
    }

    // MARK: - Actions

    private func loadSelectedMedia(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        // Heuristic: 動画サポートが有効で、Transferable として動画が取れたら動画モード
        if videoSupport != nil, let picked = try? await item.loadTransferable(type: PickedVideo.self) {
            await switchToVideo(url: picked.url)
            return
        }
        // それ以外は写真として読む
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                photoData = data
                videoURL = nil
                videoOverlayBuilder = nil
                videoPlayer?.pause()
                videoPlayer = nil
                await updatePreview()
            }
        } catch {
            print("Failed to load photo: \(error)")
        }
    }

    private func switchToVideo(url: URL) async {
        guard let videoSupport else { return }
        videoPlayer?.pause()
        videoPlayer = nil
        photoData = nil
        previewImageData = nil
        videoURL = url

        let builder = await videoSupport.prepareOverlay(url)
        videoOverlayBuilder = builder
        await rebuildPlayer()
    }

    @MainActor
    private func rebuildPlayer() async {
        guard let url = videoURL else { return }
        do {
            let asset = AVURLAsset(url: url)
            let composition: AVVideoComposition
            if let builder = videoOverlayBuilder {
                composition = try await VideoComposer.makeVideoComposition(asset: asset, overlayBuilder: builder)
            } else {
                composition = try await AVMutableVideoComposition.videoComposition(with: asset) { request in
                    request.finish(with: request.sourceImage, context: nil)
                }
            }
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = composition
            videoPlayer = AVPlayer(playerItem: item)
        } catch {
            print("Failed to build player: \(error)")
        }
    }

    private func rebuildAfterOptionsChange() async {
        if videoURL != nil, let videoSupport, let url = videoURL {
            // 動画モード: オーバーレイ再生成（オプション変更を反映）
            let builder = await videoSupport.prepareOverlay(url)
            videoOverlayBuilder = builder
            await rebuildPlayer()
        } else {
            await updatePreview()
        }
    }

    func updatePreview() async {
        let data: Data
        let newAspectRatio = selectedAspectRatio
        let centered: Bool
        if let photoData = photoData {
            data = photoData
            centered = false
        } else {
            // 写真未選択時はグラデーション背景を使用（中央レイアウト）
            guard let gradientData = ImageComposer.createGradientImageData(aspectRatio: newAspectRatio) else {
                previewImageData = nil
                return
            }
            data = gradientData
            centered = true
        }
        let newPreview = await composeImage(data, centered)
        // 画像とアスペクト比を同時に更新（1回の再描画で完了）
        previewImageData = newPreview
        displayedAspectRatio = newAspectRatio
    }

    private func saveTapped() async {
        if videoURL != nil {
            await saveVideoToPhotos()
        } else {
            await savePhotoToPhotos()
        }
    }

    private func shareTapped() async {
        if videoURL != nil {
            await shareVideo()
        } else {
            await sharePhoto()
        }
    }

    private func savePhotoToPhotos() async {
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

    private func sharePhoto() async {
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

    private func saveVideoToPhotos() async {
        guard let output = await composeVideoToTemp() else { return }

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
                request.addResource(with: .video, fileURL: output, options: nil)
            }
            videoSupport?.logSaveEvent()
            showSaveSuccess = true
        } catch {
            print("Failed to save video: \(error)")
            showSaveError = true
        }
    }

    private func shareVideo() async {
        guard let output = await composeVideoToTemp() else { return }
        await MainActor.run {
            shareItem = output
            isSharing = false
        }
        videoSupport?.logShareEvent()
    }

    /// 動画を書き出してtempURLを返す。書き出し中は isSaving/isSharing と saveProgress を更新。
    private func composeVideoToTemp() async -> URL? {
        guard let inputURL = videoURL, let builder = videoOverlayBuilder else { return nil }

        await MainActor.run {
            isSaving = true
            saveProgress = 0
        }
        // 注: 書き出し中もボタン無効化のために isSaving フラグを使用
        // shareTapped 経由でも isSaving を使うが、shareTapped は最後に isSharing=false にする
        // ここで isSaving は MainActor.run で操作する

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-composed-\(UUID().uuidString)")
            .appendingPathExtension("mov")

        do {
            _ = try await VideoComposer.compose(
                inputURL: inputURL,
                overlayBuilder: builder,
                outputURL: outputURL,
                progress: { p in
                    Task { @MainActor in self.saveProgress = p }
                }
            )
            return outputURL
        } catch {
            print("Failed to compose video: \(error)")
            await MainActor.run {
                isSaving = false
                showSaveError = true
            }
            return nil
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
