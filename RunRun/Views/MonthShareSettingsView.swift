import SwiftUI

/// 月間統計の共有画像に出力するデータの選択状態
struct MonthExportOptions: Equatable, Hashable {
    var showPeriod = true
    var showDistance = true
    var showDuration = true
    var showRunCount = true
    var showCalories = true
    var showPace = true
    var showAvgDistance = true
    var showAvgDuration = true
    var showProgressChart = true
}

/// 月間統計の共有データ
struct MonthlyShareData {
    let period: String
    let totalDistance: String
    let runCount: Int
    let totalDuration: String
    let averagePace: String
    let averageDistance: String
    let averageDuration: String
    let totalCalories: String?
    let cumulativeData: [(day: Int, distance: Double)]
}

struct MonthShareSettingsView: View {
    let shareData: MonthlyShareData
    let isOwnData: Bool
    @Binding var isPresented: Bool

    // データ選択（保存される）
    @AppStorage("monthShare.showPeriod") private var showPeriod = true
    @AppStorage("monthShare.showDistance") private var showDistance = true
    @AppStorage("monthShare.showDuration") private var showDuration = true
    @AppStorage("monthShare.showRunCount") private var showRunCount = true
    @AppStorage("monthShare.showCalories") private var showCalories = true
    @AppStorage("monthShare.showPace") private var showPace = true
    @AppStorage("monthShare.showAvgDistance") private var showAvgDistance = true
    @AppStorage("monthShare.showAvgDuration") private var showAvgDuration = true
    @AppStorage("monthShare.showProgressChart") private var showProgressChart = true

    private var options: MonthExportOptions {
        MonthExportOptions(
            showPeriod: showPeriod,
            showDistance: showDistance,
            showDuration: showDuration,
            showRunCount: showRunCount,
            showCalories: showCalories,
            showPace: showPace,
            showAvgDistance: showAvgDistance,
            showAvgDuration: showAvgDuration,
            showProgressChart: showProgressChart && !shareData.cumulativeData.isEmpty
        )
    }

    var body: some View {
        ShareSettingsContainer(
            isPresented: $isPresented,
            analyticsScreenName: "MonthShareSettings",
            optionsChangeId: AnyHashable(options),
            composeImage: { data in
                await ImageComposer.composeMonthlyStats(imageData: data, shareData: shareData, options: options)
            },
            logSaveEvent: {
                AnalyticsService.logEvent("month_share_image_saved", parameters: [
                    "show_period": options.showPeriod,
                    "show_distance": options.showDistance,
                    "show_run_count": options.showRunCount,
                    "show_duration": options.showDuration,
                    "show_pace": options.showPace,
                    "show_avg_distance": options.showAvgDistance,
                    "show_avg_duration": options.showAvgDuration,
                    "show_calories": options.showCalories,
                    "show_progress_chart": options.showProgressChart
                ])
            },
            logShareEvent: {
                AnalyticsService.logEvent("month_share_image_shared", parameters: [
                    "show_period": options.showPeriod,
                    "show_distance": options.showDistance,
                    "show_run_count": options.showRunCount,
                    "show_duration": options.showDuration,
                    "show_pace": options.showPace,
                    "show_avg_distance": options.showAvgDistance,
                    "show_avg_duration": options.showAvgDuration,
                    "show_calories": options.showCalories,
                    "show_progress_chart": options.showProgressChart
                ])
            }
        ) {
            dataOptionsSection
        }
    }

    private var dataOptionsSection: some View {
        ShareOptionsSection {
            if !shareData.cumulativeData.isEmpty {
                ShareOptionRow(title: String(localized: "Progress Chart"), isOn: $showProgressChart)
                Divider()
            }
            ShareOptionRow(title: String(localized: "Month"), isOn: $showPeriod)
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
