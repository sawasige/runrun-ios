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
    @State private var previewFailed = false
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var saveProgress: Float = 0  // 動画書き出し時の進捗
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showPermissionDenied = false
    @State private var shareItem: IdentifiableURL?

    // 連続選択や設定変更時に古いcompose結果でプレビューを上書きしないためのキャンセル管理
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationTitle(String(localized: "Share Settings"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(item: $shareItem) { item in
                    ShareSheet(activityItems: [item.url], onComplete: { _ in
                        try? FileManager.default.removeItem(at: item.url)
                    })
                }
                .onChange(of: selectedPickerItem) { _, newItem in
                    guard let newItem else { return }
                    loadTask?.cancel()
                    loadTask = Task { await loadSelectedMedia(from: newItem) }
                }
                .onChange(of: optionsChangeId) { _, _ in
                    loadTask?.cancel()
                    loadTask = Task { await rebuildAfterOptionsChange() }
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
                .onDisappear {
                    cleanupVideoTempFile()
                }
        }
    }

    /// PhotosPickerからコピーしてきた一時動画ファイルを削除
    private func cleanupVideoTempFile() {
        guard let url = videoURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                previewSection
                if photoData == nil && videoURL == nil {
                    aspectRatioPicker
                }
                backgroundPickerSection
                if (isSaving || isSharing) && videoURL != nil {
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
            } else if previewFailed {
                errorPreview
            } else {
                loadingPreview
            }
        }
        .task {
            // 初期表示時にグラデーションでプレビュー生成
            if previewImageData == nil && videoPlayer == nil && !previewFailed {
                await updatePreview()
            }
        }
    }

    private var errorPreview: some View {
        GeometryReader { geometry in
            let height = geometry.size.width
            let width = height * displayedAspectRatio.size.width / displayedAspectRatio.size.height

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: width, height: height)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Couldn't generate preview")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            previewFailed = false
                            loadTask?.cancel()
                            loadTask = Task { await updatePreview() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
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
            loadTask?.cancel()
            loadTask = Task { await updatePreview() }
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
        cleanupVideoTempFile()
        photoData = nil
        videoURL = nil
        videoOverlayBuilder = nil
        videoPlayer?.pause()
        videoPlayer = nil
        selectedPickerItem = nil
        Task { await updatePreview() }
    }

    // MARK: - Actions

    private func loadSelectedMedia(from item: PhotosPickerItem) async {
        // 同じ写真を再選択できるよう selection を即座にクリア
        // onChange側で newItem == nil をスキップしているので無限ループにはならない
        selectedPickerItem = nil

        // 画像コンポーネントを持たず動画のみのアイテムだけ動画モードへ。
        // Live Photo は image にも conform するため写真扱いにする。
        let supportsImage = item.supportedContentTypes.contains { $0.conforms(to: .image) }
        let supportsMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if videoSupport != nil, supportsMovie, !supportsImage,
           let picked = try? await item.loadTransferable(type: PickedVideo.self) {
            if Task.isCancelled { return }
            await switchToVideo(url: picked.url)
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if Task.isCancelled { return }
                cleanupVideoTempFile()
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
        cleanupVideoTempFile()
        videoPlayer?.pause()
        videoPlayer = nil
        photoData = nil
        previewImageData = nil
        videoURL = url

        let builder = await videoSupport.prepareOverlay(url)
        if Task.isCancelled { return }
        videoOverlayBuilder = builder
        do {
            try await rebuildPlayer()
        } catch {
            print("Failed to switch to video: \(error)")
            // ロールバック: 動画モード状態を解除して写真未選択へ戻す
            cleanupVideoTempFile()
            videoURL = nil
            videoOverlayBuilder = nil
            await updatePreview()
        }
    }

    @MainActor
    private func rebuildPlayer() async throws {
        guard let url = videoURL else { return }
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

        // 既存プレイヤーは再利用してフラッシュを避ける
        if let existing = videoPlayer {
            existing.pause()
            existing.replaceCurrentItem(with: item)
            existing.play()
        } else {
            videoPlayer = AVPlayer(playerItem: item)
        }
    }

    private func rebuildAfterOptionsChange() async {
        if videoURL != nil, let videoSupport, let url = videoURL {
            // 動画モード: オーバーレイ再生成（オプション変更を反映）
            let builder = await videoSupport.prepareOverlay(url)
            if Task.isCancelled { return }
            videoOverlayBuilder = builder
            do {
                try await rebuildPlayer()
            } catch {
                print("Failed to rebuild player: \(error)")
            }
        } else {
            await updatePreview()
        }
    }

    func updatePreview() async {
        // リトライや再生成時に古い失敗状態が残らないようリセット（ローディング表示に戻す）
        previewFailed = false

        let data: Data
        let newAspectRatio = selectedAspectRatio
        let centered: Bool
        if let photoData = photoData {
            data = photoData
            centered = false
        } else {
            // 写真未選択時はグラデーション背景を使用（中央レイアウト）
            guard let gradientData = ImageComposer.createGradientImageData(aspectRatio: newAspectRatio) else {
                if Task.isCancelled { return }
                previewImageData = nil
                previewFailed = true
                return
            }
            data = gradientData
            centered = true
        }
        let newPreview = await composeImage(data, centered)
        if Task.isCancelled { return }
        // 画像とアスペクト比を同時に更新（1回の再描画で完了）
        previewImageData = newPreview
        displayedAspectRatio = newAspectRatio
        previewFailed = (newPreview == nil)
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
        defer { isSharing = false }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")

        do {
            try data.write(to: tempURL)
            shareItem = IdentifiableURL(url: tempURL)
            logShareEvent()
        } catch {
            print("Failed to create temp file: \(error)")
        }
    }

    private func saveVideoToPhotos() async {
        // 重い書き出しの前に認可確認（拒否されたら無駄な計算を回避）
        let authorized = await PhotoLibraryService.ensureAuthorization()
        guard authorized else {
            showPermissionDenied = true
            return
        }

        isSaving = true
        defer {
            isSaving = false
            saveProgress = 0
        }

        guard let output = await composeVideoToTemp() else { return }
        defer { try? FileManager.default.removeItem(at: output) }

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
        isSharing = true
        defer {
            isSharing = false
            saveProgress = 0
        }

        guard let output = await composeVideoToTemp() else { return }
        shareItem = IdentifiableURL(url: output)
        videoSupport?.logShareEvent()
    }

    /// 動画を書き出してtempURLを返す。saveProgress を更新するが、isSaving/isSharing は呼び出し側で管理する。
    private func composeVideoToTemp() async -> URL? {
        guard let inputURL = videoURL, let builder = videoOverlayBuilder else { return nil }

        saveProgress = 0

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
            showSaveError = true
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
