import SwiftUI
import PhotosUI
import Photos

/// 共有画像に出力するデータの選択状態
struct ExportOptions: Equatable {
    var showDate = true
    var showStartTime = true
    var showDistance = true
    var showDuration = true
    var showPace = true
    var showHeartRate = true
    var showSteps = true
    var showCalories = true
}

struct RunShareSettingsView: View {
    let record: RunningRecord
    @Binding var isPresented: Bool

    // 写真選択
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    // データ選択（保存される）
    @AppStorage("runShare.showDate") private var showDate = true
    @AppStorage("runShare.showStartTime") private var showStartTime = true
    @AppStorage("runShare.showDistance") private var showDistance = true
    @AppStorage("runShare.showDuration") private var showDuration = true
    @AppStorage("runShare.showPace") private var showPace = true
    @AppStorage("runShare.showHeartRate") private var showHeartRate = true
    @AppStorage("runShare.showSteps") private var showSteps = true
    @AppStorage("runShare.showCalories") private var showCalories = true

    private var options: ExportOptions {
        ExportOptions(
            showDate: showDate,
            showStartTime: showStartTime,
            showDistance: showDistance,
            showDuration: showDuration,
            showPace: showPace,
            showHeartRate: showHeartRate,
            showSteps: showSteps,
            showCalories: showCalories
        )
    }

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
            ScrollView {
                VStack(spacing: 24) {
                    // プレビュー
                    previewSection

                    // 写真選択ボタン
                    photoPickerButton

                    // データ選択
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
                Task {
                    await loadSelectedPhoto(from: newItem)
                }
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
            .analyticsScreen("ShareSettings")
        }
    }

    // MARK: - Preview Section

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

    // MARK: - Data Options Section

    private var dataOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data to Export")
                .font(.headline)

            VStack(spacing: 0) {
                optionRow(title: String(localized: "Run Date"), isOn: $showDate)
                Divider()
                optionRow(title: String(localized: "Start Time"), isOn: $showStartTime)
                Divider()
                optionRow(title: String(localized: "Distance"), isOn: $showDistance)
                Divider()
                optionRow(title: String(localized: "Time"), isOn: $showDuration)
                Divider()
                optionRow(title: String(localized: "Pace"), isOn: $showPace)

                if record.averageHeartRate != nil {
                    Divider()
                    optionRow(title: String(localized: "Avg Heart Rate"), isOn: $showHeartRate)
                }
                if record.stepCount != nil {
                    Divider()
                    optionRow(title: String(localized: "Steps"), isOn: $showSteps)
                }
                if record.caloriesBurned != nil {
                    Divider()
                    optionRow(title: String(localized: "Calories"), isOn: $showCalories)
                }
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

    private func updatePreview() async {
        guard let data = photoData else {
            previewImageData = nil
            return
        }

        previewImageData = await ImageComposer.composeAsHEIF(
            imageData: data,
            record: record,
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

            AnalyticsService.logEvent("share_image_saved", parameters: [
                "show_date": options.showDate,
                "show_start_time": options.showStartTime,
                "show_distance": options.showDistance,
                "show_duration": options.showDuration,
                "show_pace": options.showPace,
                "show_heart_rate": options.showHeartRate,
                "show_steps": options.showSteps,
                "show_calories": options.showCalories
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

        // 一時ファイルに保存してURLをシェア（HDR維持のため）
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")

        do {
            try data.write(to: tempURL)
            await MainActor.run {
                shareItem = tempURL
                isSharing = false
            }

            AnalyticsService.logEvent("share_image_shared", parameters: [
                "show_date": options.showDate,
                "show_start_time": options.showStartTime,
                "show_distance": options.showDistance,
                "show_duration": options.showDuration,
                "show_pace": options.showPace,
                "show_heart_rate": options.showHeartRate,
                "show_steps": options.showSteps,
                "show_calories": options.showCalories
            ])
        } catch {
            print("Failed to create temp file: \(error)")
            await MainActor.run {
                isSharing = false
            }
        }
    }
}

#Preview {
    RunShareSettingsView(
        record: RunningRecord(
            id: UUID(),
            date: Date(),
            distanceInMeters: 5230,
            durationInSeconds: 1845,
            caloriesBurned: 320,
            averageHeartRate: 155,
            stepCount: 5160
        ),
        isPresented: .constant(true)
    )
}
