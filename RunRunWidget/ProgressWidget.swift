import WidgetKit
import SwiftUI
import Charts

// MARK: - Timeline Provider

struct ProgressProvider: TimelineProvider {
    private var defaultUseMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(
            date: Date(),
            cumulativeDistances: [
                CumulativeDataPoint(day: 1, distance: 0),
                CumulativeDataPoint(day: 5, distance: 10),
                CumulativeDataPoint(day: 10, distance: 25),
                CumulativeDataPoint(day: 15, distance: 35)
            ],
            previousMonthCumulativeDistances: [
                CumulativeDataPoint(day: 1, distance: 0),
                CumulativeDataPoint(day: 8, distance: 15),
                CumulativeDataPoint(day: 20, distance: 40)
            ],
            totalDistance: 35.0,
            useMetric: defaultUseMetric
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let entry = loadEntry()
        // 30分ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> ProgressEntry {
        let data = WidgetDataStore.shared.load()
        return ProgressEntry(
            date: Date(),
            cumulativeDistances: data?.cumulativeDistances ?? [],
            previousMonthCumulativeDistances: data?.previousMonthCumulativeDistances ?? [],
            totalDistance: data?.totalDistance ?? 0,
            useMetric: data?.useMetric ?? defaultUseMetric
        )
    }
}

// MARK: - Entry

struct ProgressEntry: TimelineEntry {
    let date: Date
    let cumulativeDistances: [CumulativeDataPoint]
    let previousMonthCumulativeDistances: [CumulativeDataPoint]
    let totalDistance: Double
    let useMetric: Bool
}

// MARK: - Widget View

struct ProgressWidgetEntryView: View {
    var entry: ProgressProvider.Entry

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: entry.date)
    }

    private var formattedDistance: String {
        if entry.useMetric {
            return String(format: "%.1f km", entry.totalDistance)
        } else {
            let miles = entry.totalDistance * 0.621371
            return String(format: "%.1f mi", miles)
        }
    }

    private var hasData: Bool {
        !entry.cumulativeDistances.isEmpty
    }

    private static let runColor = Color("RunColor")
    private static let kmToMiles = 0.621371

    /// グラフ用に距離を変換（マイル表示の場合）
    private func convertDistance(_ km: Double) -> Double {
        entry.useMetric ? km : km * Self.kmToMiles
    }

    var body: some View {
        if hasData {
            contentView
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Open app to sync data")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var contentView: some View {
        HStack(spacing: 12) {
            // チャート部分
            chartView
                .frame(maxWidth: .infinity)

            // 統計部分
            VStack(alignment: .leading, spacing: 4) {
                Text(monthName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedDistance)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                Spacer()

                // 凡例
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Self.runColor)
                            .frame(width: 12, height: 2)
                        Text("This month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        DashedLine()
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                            .frame(width: 12, height: 2)
                        Text("Last month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 90)
        }
        .padding()
    }

    private var chartView: some View {
        Chart {
            // 前月の累積距離（比較用）- 先に描画
            ForEach(entry.previousMonthCumulativeDistances, id: \.day) { data in
                LineMark(
                    x: .value("Day", data.day),
                    y: .value("Distance", convertDistance(data.distance)),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }

            // 当月のエリア（塗りつぶし）
            ForEach(entry.cumulativeDistances, id: \.day) { data in
                AreaMark(
                    x: .value("Day", data.day),
                    y: .value("Distance", convertDistance(data.distance)),
                    series: .value("Series", "currentArea")
                )
                .foregroundStyle(Self.runColor.opacity(0.15))
            }

            // 当月の線（最前面に描画）
            ForEach(entry.cumulativeDistances, id: \.day) { data in
                LineMark(
                    x: .value("Day", data.day),
                    y: .value("Distance", convertDistance(data.distance)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Self.runColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXScale(domain: 1...31)
        .chartXAxis {
            AxisMarks(values: [1, 15, 31]) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(.hidden)
    }
}

// MARK: - Dashed Line Shape

/// 凡例用の水平破線
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Widget Configuration

struct ProgressWidget: Widget {
    let kind: String = "ProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Distance Progress")
        .description("Shows your cumulative distance for this month.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    ProgressWidget()
} timeline: {
    ProgressEntry(
        date: Date(),
        cumulativeDistances: [
            CumulativeDataPoint(day: 1, distance: 0),
            CumulativeDataPoint(day: 3, distance: 5.2),
            CumulativeDataPoint(day: 5, distance: 10.5),
            CumulativeDataPoint(day: 8, distance: 18.3),
            CumulativeDataPoint(day: 10, distance: 25.0),
            CumulativeDataPoint(day: 12, distance: 32.5),
            CumulativeDataPoint(day: 14, distance: 38.2)
        ],
        previousMonthCumulativeDistances: [
            CumulativeDataPoint(day: 1, distance: 0),
            CumulativeDataPoint(day: 5, distance: 8.0),
            CumulativeDataPoint(day: 10, distance: 20.0),
            CumulativeDataPoint(day: 15, distance: 28.0),
            CumulativeDataPoint(day: 20, distance: 35.0),
            CumulativeDataPoint(day: 25, distance: 42.0),
            CumulativeDataPoint(day: 30, distance: 50.0)
        ],
        totalDistance: 38.2,
        useMetric: true
    )
}
