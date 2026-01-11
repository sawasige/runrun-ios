import SwiftUI
import PhotosUI
import Photos

/// 年間統計の共有画像に出力するデータの選択状態
struct YearExportOptions: Equatable {
    var showYear = true
    var showDistance = true
    var showDuration = true
    var showRunCount = true
    var showCalories = true
    var showPace = true
    var showAvgDistance = true
    var showAvgDuration = true
}

/// 年間統計の共有データ
struct YearlyShareData {
    let year: String
    let totalDistance: String
    let runCount: Int
    let totalDuration: String
    let averagePace: String
    let averageDistance: String
    let averageDuration: String
    let totalCalories: String?
}

struct YearShareSettingsView: View {
    let shareData: YearlyShareData
    let isOwnData: Bool
    @Binding var isPresented: Bool

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var previewImageData: Data?
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false

    // データ選択（保存される）
    @AppStorage("yearShare.showYear") private var showYear = true
    @AppStorage("yearShare.showDistance") private var showDistance = true
    @AppStorage("yearShare.showDuration") private var showDuration = true
    @AppStorage("yearShare.showRunCount") private var showRunCount = true
    @AppStorage("yearShare.showCalories") private var showCalories = true
    @AppStorage("yearShare.showPace") private var showPace = true
    @AppStorage("yearShare.showAvgDistance") private var showAvgDistance = true
    @AppStorage("yearShare.showAvgDuration") private var showAvgDuration = true

    private var options: YearExportOptions {
        YearExportOptions(
            showYear: showYear,
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
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(photoData == nil || isSaving)
                }
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
            } message: {
                Text("Please allow photo library access in Settings.")
            }
            .analyticsScreen("YearShareSettings")
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
                optionRow(title: String(localized: "Year"), isOn: $showYear)
                Divider()
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
        previewImageData = await ImageComposer.composeYearlyStats(
            imageData: data,
            shareData: shareData,
            options: options
        )
    }

    private func saveToPhotos() async {
        guard let data = previewImageData else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }

            AnalyticsService.logEvent("year_share_image_saved", parameters: [
                "show_year": options.showYear,
                "show_distance": options.showDistance,
                "show_run_count": options.showRunCount,
                "show_duration": options.showDuration,
                "show_pace": options.showPace,
                "show_avg_distance": options.showAvgDistance,
                "show_avg_duration": options.showAvgDuration,
                "show_calories": options.showCalories
            ])

            showSaveSuccess = true
        } catch {
            print("Failed to save: \(error)")
            showSaveError = true
        }
    }
}
