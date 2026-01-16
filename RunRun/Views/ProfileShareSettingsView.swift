import SwiftUI

/// プロフィール統計の共有画像に出力するデータの選択状態
struct ProfileExportOptions: Equatable, Hashable {
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
        ShareSettingsContainer(
            isPresented: $isPresented,
            analyticsScreenName: "ProfileShareSettings",
            optionsChangeId: AnyHashable(options),
            composeImage: { data in
                await ImageComposer.composeProfileStats(imageData: data, shareData: shareData, options: options)
            },
            logSaveEvent: {
                AnalyticsService.logEvent("profile_share_image_saved", parameters: [
                    "show_distance": options.showDistance,
                    "show_duration": options.showDuration,
                    "show_run_count": options.showRunCount,
                    "show_calories": options.showCalories,
                    "show_pace": options.showPace,
                    "show_avg_distance": options.showAvgDistance,
                    "show_avg_duration": options.showAvgDuration
                ])
            },
            logShareEvent: {
                AnalyticsService.logEvent("profile_share_image_shared", parameters: [
                    "show_distance": options.showDistance,
                    "show_duration": options.showDuration,
                    "show_run_count": options.showRunCount,
                    "show_calories": options.showCalories,
                    "show_pace": options.showPace,
                    "show_avg_distance": options.showAvgDistance,
                    "show_avg_duration": options.showAvgDuration
                ])
            }
        ) {
            dataOptionsSection
        }
    }

    private var dataOptionsSection: some View {
        ShareOptionsSection {
            ShareOptionRow(title: String(localized: "Total Distance"), isOn: $showDistance)
            Divider()
            ShareOptionRow(title: String(localized: "Total Time"), isOn: $showDuration)
            Divider()
            ShareOptionRow(title: String(localized: "Total Runs"), isOn: $showRunCount)
            if isOwnData && shareData.totalCalories != nil {
                Divider()
                ShareOptionRow(title: String(localized: "Total Energy"), isOn: $showCalories)
            }
            Divider()
            ShareOptionRow(title: String(localized: "Avg Pace"), isOn: $showPace)
            Divider()
            ShareOptionRow(title: String(localized: "Avg Distance"), isOn: $showAvgDistance)
            Divider()
            ShareOptionRow(title: String(localized: "Avg Time"), isOn: $showAvgDuration)
        }
    }
}
