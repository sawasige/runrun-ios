import SwiftUI

/// 年間統計の共有画像に出力するデータの選択状態
struct YearExportOptions: Equatable, Hashable {
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
        ShareSettingsContainer(
            isPresented: $isPresented,
            analyticsScreenName: "YearShareSettings",
            optionsChangeId: AnyHashable(options),
            composeImage: { data in
                await ImageComposer.composeYearlyStats(imageData: data, shareData: shareData, options: options)
            },
            logSaveEvent: {
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
            },
            logShareEvent: {
                AnalyticsService.logEvent("year_share_image_shared", parameters: [
                    "show_year": options.showYear,
                    "show_distance": options.showDistance,
                    "show_run_count": options.showRunCount,
                    "show_duration": options.showDuration,
                    "show_pace": options.showPace,
                    "show_avg_distance": options.showAvgDistance,
                    "show_avg_duration": options.showAvgDuration,
                    "show_calories": options.showCalories
                ])
            }
        ) {
            dataOptionsSection
        }
    }

    private var dataOptionsSection: some View {
        ShareOptionsSection {
            ShareOptionRow(title: String(localized: "Year"), isOn: $showYear)
            Divider()
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
