import SwiftUI
import CoreLocation

/// 共有画像に出力するデータの選択状態
struct ExportOptions: Equatable, Hashable {
    var showDate = true
    var showStartTime = true
    var showDistance = true
    var showDuration = true
    var showPace = true
    var showHeartRate = true
    var showSteps = true
    var showCalories = true
    var showRoute = true
}

struct RunShareSettingsView: View {
    let record: RunningRecord
    let routeCoordinates: [CLLocationCoordinate2D]
    @Binding var isPresented: Bool

    // データ選択（保存される）
    @AppStorage("runShare.showDate") private var showDate = true
    @AppStorage("runShare.showStartTime") private var showStartTime = true
    @AppStorage("runShare.showDistance") private var showDistance = true
    @AppStorage("runShare.showDuration") private var showDuration = true
    @AppStorage("runShare.showPace") private var showPace = true
    @AppStorage("runShare.showHeartRate") private var showHeartRate = true
    @AppStorage("runShare.showSteps") private var showSteps = true
    @AppStorage("runShare.showCalories") private var showCalories = true
    @AppStorage("runShare.showRoute") private var showRoute = true

    private var options: ExportOptions {
        ExportOptions(
            showDate: showDate,
            showStartTime: showStartTime,
            showDistance: showDistance,
            showDuration: showDuration,
            showPace: showPace,
            showHeartRate: showHeartRate,
            showSteps: showSteps,
            showCalories: showCalories,
            showRoute: showRoute && !routeCoordinates.isEmpty
        )
    }

    var body: some View {
        ShareSettingsContainer(
            isPresented: $isPresented,
            analyticsScreenName: "ShareSettings",
            optionsChangeId: AnyHashable(options),
            composeImage: { data in
                await ImageComposer.composeAsHEIF(imageData: data, record: record, options: options, routeCoordinates: routeCoordinates)
            },
            logSaveEvent: {
                AnalyticsService.logEvent("share_image_saved", parameters: [
                    "show_date": options.showDate,
                    "show_start_time": options.showStartTime,
                    "show_distance": options.showDistance,
                    "show_duration": options.showDuration,
                    "show_pace": options.showPace,
                    "show_heart_rate": options.showHeartRate,
                    "show_steps": options.showSteps,
                    "show_calories": options.showCalories,
                    "show_route": options.showRoute
                ])
            },
            logShareEvent: {
                AnalyticsService.logEvent("share_image_shared", parameters: [
                    "show_date": options.showDate,
                    "show_start_time": options.showStartTime,
                    "show_distance": options.showDistance,
                    "show_duration": options.showDuration,
                    "show_pace": options.showPace,
                    "show_heart_rate": options.showHeartRate,
                    "show_steps": options.showSteps,
                    "show_calories": options.showCalories,
                    "show_route": options.showRoute
                ])
            }
        ) {
            dataOptionsSection
        }
    }

    private var dataOptionsSection: some View {
        ShareOptionsSection {
            if !routeCoordinates.isEmpty {
                ShareOptionRow(title: String(localized: "Route"), isOn: $showRoute)
                Divider()
            }
            ShareOptionRow(title: String(localized: "Run Date"), isOn: $showDate)
            Divider()
            ShareOptionRow(title: String(localized: "Start Time"), isOn: $showStartTime)
            Divider()
            ShareOptionRow(title: String(localized: "Distance"), isOn: $showDistance)
            Divider()
            ShareOptionRow(title: String(localized: "Time"), isOn: $showDuration)
            Divider()
            ShareOptionRow(title: String(localized: "Pace"), isOn: $showPace)

            if record.averageHeartRate != nil {
                Divider()
                ShareOptionRow(title: String(localized: "Avg Heart Rate"), isOn: $showHeartRate)
            }
            if record.stepCount != nil {
                Divider()
                ShareOptionRow(title: String(localized: "Steps"), isOn: $showSteps)
            }
            if record.caloriesBurned != nil {
                Divider()
                ShareOptionRow(title: String(localized: "Calories"), isOn: $showCalories)
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
        routeCoordinates: [],
        isPresented: .constant(true)
    )
}
