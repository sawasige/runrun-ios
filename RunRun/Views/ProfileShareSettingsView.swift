import SwiftUI
import PhotosUI
import Photos

/// プロフィール統計の共有画像に出力するデータの選択状態
struct ProfileExportOptions: Equatable {
    var showDistance = true
    var showDuration = true
    var showRunCount = true
    var showCalories = true
    var showPace = true
    var showAvgDistance = true
    var showAvgDuration = true
}

/// プロフィール統計の共有データ
struct ProfileShareData {
    let displayName: String
    let totalDistance: String
    let runCount: Int
    let totalDuration: String
    let averagePace: String
    let averageDistance: String
    let averageDuration: String
    let totalCalories: String?
}

struct ProfileShareSettingsView: View {
    let shareData: ProfileShareData
    let isOwnData: Bool
    @Binding var isPresented: Bool

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var previewImageData: Data?
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showPermissionDenied = false
    @State private var shareItem: URL?

    // データ選択（保存される）
    @AppStorage("profileShare.showDistance") private var showDistance = true
    @AppStorage("profileShare.showDuration") private var showDuration = true
    @AppStorage("profileShare.showRunCount") private var showRunCount = true
    @AppStorage("profileShare.showCalories") private var showCalories = true
    @AppStorage("profileShare.showPace") private var showPace = true
    @AppStorage("profileShare.showAvgDistance") private var showAvgDistance = true
    @AppStorage("profileShare.showAvgDuration") private var showAvgDuration = true

    private var options: ProfileExportOptions {
        ProfileExportOptions(
            showDistance: showDistance,
            showDuration: showDuration,
            showRunCount: showRunCount,
            showCalories: showCalories,
            showPace: showPace,
            showAvgDistance: showAvgDistance,
            showAvgDuration: showAvgDuration
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    photoPickerButton
                    dataOptionsSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "Share Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 20) {
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
                }
            }
            .sheet(item: $shareItem) { url in
                ShareSheet(activityItems: [url])
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadSelectedPhoto(from: newItem) }
            }
            .onChange(of: options) { _, _ in
                Task { await updatePreview() }
            }
            .alert(String(localized: "Saved"), isPresented: $showSaveSuccess) {
                Button("OK") {
                    isPresented = false
                }
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
            .analyticsScreen("ProfileShareSettings")
        }
    }

    private var previewSection: some View {
        Group {
            if let previewData = previewImageData {
                HDRImageView(imageData: previewData)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
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
        }
    }

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

    private var dataOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data to Export")
                .font(.headline)

            VStack(spacing: 0) {
                optionRow(title: String(localized: "Total Distance"), isOn: $showDistance)
                Divider()
                optionRow(title: String(localized: "Total Time"), isOn: $showDuration)
                Divider()
                optionRow(title: String(localized: "Total Runs"), isOn: $showRunCount)
                if isOwnData && shareData.totalCalories != nil {
                    Divider()
                    optionRow(title: String(localized: "Total Energy"), isOn: $showCalories)
                }
                Divider()
                optionRow(title: String(localized: "Avg Pace"), isOn: $showPace)
                Divider()
                optionRow(title: String(localized: "Avg Distance"), isOn: $showAvgDistance)
                Divider()
                optionRow(title: String(localized: "Avg Time"), isOn: $showAvgDuration)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func optionRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

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

    private func updatePreview() async {
        guard let data = photoData else {
            previewImageData = nil
            return
        }
        previewImageData = await ImageComposer.composeProfileStats(
            imageData: data,
            shareData: shareData,
            options: options
        )
    }

    private func saveToPhotos() async {
        guard let data = previewImageData else { return }

        // 許可を確認
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

            AnalyticsService.logEvent("profile_share_image_saved", parameters: [
                "show_distance": options.showDistance,
                "show_duration": options.showDuration,
                "show_run_count": options.showRunCount,
                "show_calories": options.showCalories,
                "show_pace": options.showPace,
                "show_avg_distance": options.showAvgDistance,
                "show_avg_duration": options.showAvgDuration
            ])

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

            AnalyticsService.logEvent("profile_share_image_shared", parameters: [
                "show_distance": options.showDistance,
                "show_duration": options.showDuration,
                "show_run_count": options.showRunCount,
                "show_calories": options.showCalories,
                "show_pace": options.showPace,
                "show_avg_distance": options.showAvgDistance,
                "show_avg_duration": options.showAvgDuration
            ])
        } catch {
            print("Failed to create temp file: \(error)")
            await MainActor.run {
                isSharing = false
            }
        }
    }
}
