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

    // データ選択
    @State private var options = ExportOptions()

    // プレビュー・保存
    @State private var previewImageData: Data?
    @State private var isSaving = false
    @State private var showSaveSuccess = false

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
            .navigationTitle("共有設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveToPhotos()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(photoData == nil || isSaving)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadSelectedPhoto(from: newItem)
                }
            }
            .onChange(of: options) { _, _ in
                Task { await updatePreview() }
            }
            .alert("保存しました", isPresented: $showSaveSuccess) {
                Button("OK") {
                    isPresented = false
                }
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
                            Text("写真を選択してください")
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
            Label(photoData == nil ? "写真を選択" : "写真を変更", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Data Options Section

    private var dataOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出力するデータ")
                .font(.headline)

            VStack(spacing: 0) {
                optionRow(title: "ランニング日付", isOn: $options.showDate)
                Divider()
                optionRow(title: "スタート時間", isOn: $options.showStartTime)
                Divider()
                optionRow(title: "距離", isOn: $options.showDistance)
                Divider()
                optionRow(title: "タイム", isOn: $options.showDuration)
                Divider()
                optionRow(title: "ペース", isOn: $options.showPace)

                if record.averageHeartRate != nil {
                    Divider()
                    optionRow(title: "平均心拍数", isOn: $options.showHeartRate)
                }
                if record.stepCount != nil {
                    Divider()
                    optionRow(title: "歩数", isOn: $options.showSteps)
                }
                if record.caloriesBurned != nil {
                    Divider()
                    optionRow(title: "消費カロリー", isOn: $options.showCalories)
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
