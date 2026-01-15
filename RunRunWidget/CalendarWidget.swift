import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CalendarProvider: TimelineProvider {
    private var defaultUseMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 12, 15], totalDistance: 42.5, totalDuration: 3600 * 4, useMetric: defaultUseMetric)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let entry = loadEntry()
        // 1時間ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> CalendarEntry {
        let data = WidgetDataStore.shared.load()
        return CalendarEntry(
            date: Date(),
            runDays: data?.runDays ?? [],
            totalDistance: data?.totalDistance ?? 0,
            totalDuration: data?.totalDuration ?? 0,
            useMetric: data?.useMetric ?? defaultUseMetric
        )
    }
}

// MARK: - Entry

struct CalendarEntry: TimelineEntry {
    let date: Date
    let runDays: Set<Int>
    let totalDistance: Double
    let totalDuration: TimeInterval
    let useMetric: Bool
}

// MARK: - Widget View

struct CalendarWidgetEntryView: View {
    var entry: CalendarProvider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var year: Int {
        calendar.component(.year, from: entry.date)
    }

    private var month: Int {
        calendar.component(.month, from: entry.date)
    }

    private var today: Int {
        calendar.component(.day, from: entry.date)
    }

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

    private var formattedDuration: String {
        let totalSeconds = Int(entry.totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "%dh %dm"), hours, minutes)
        } else {
            return String(format: String(localized: "%dm"), minutes)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        return Array(symbols[firstWeekday - 1..<symbols.count] + symbols[0..<firstWeekday - 1])
    }

    private var calendarCells: [(id: Int, day: Int?, weekday: Int)] {
        var cells: [(id: Int, day: Int?, weekday: Int)] = []

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components) else { return cells }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let adjustedFirstWeekday = (firstWeekday - calendar.firstWeekday + 7) % 7

        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        var id = 0
        // 空セル
        for i in 0..<adjustedFirstWeekday {
            cells.append((id: id, day: nil, weekday: (i + calendar.firstWeekday - 1) % 7 + 1))
            id += 1
        }
        // 日付セル
        for day in 1...daysInMonth {
            let weekday = (adjustedFirstWeekday + day - 1) % 7 + 1
            cells.append((id: id, day: day, weekday: weekday))
            id += 1
        }

        return cells
    }

    private var hasData: Bool {
        // データが読み込まれているかチェック（距離0かつラン日なしはデータ未同期とみなす）
        !(entry.runDays.isEmpty && entry.totalDistance == 0)
    }

    var body: some View {
        if hasData {
            switch family {
            case .systemSmall:
                smallBody
            case .systemLarge:
                largeBody
            default:
                mediumBody
            }
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
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

    // MARK: - Small Layout

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(entry.runDays.count)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)

            Text("Runs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formattedDistance)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Self.runColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Medium Layout

    private var mediumBody: some View {
        HStack(spacing: 12) {
            // カレンダー部分
            VStack(spacing: 4) {
                // 曜日ヘッダー
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(weekdayHeaderColor(index: index))
                    }
                }

                // 日付グリッド
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(calendarCells, id: \.id) { cell in
                        if let day = cell.day {
                            dayCell(day: day, weekday: cell.weekday, size: .medium)
                        } else {
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                }
            }
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

                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.runColor)
                        .frame(width: 8, height: 8)
                    Text("\(entry.runDays.count) runs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90)
        }
        .padding()
    }

    // MARK: - Large Layout

    private var largeBody: some View {
        VStack(spacing: 12) {
            // ヘッダー
            HStack {
                Text(monthYearName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Spacer()
            }

            // カレンダー部分
            VStack(spacing: 6) {
                // 曜日ヘッダー
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(weekdayHeaderColor(index: index))
                    }
                }

                // 日付グリッド
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(calendarCells, id: \.id) { cell in
                        if let day = cell.day {
                            dayCell(day: day, weekday: cell.weekday, size: .large)
                        } else {
                            Color.clear
                                .frame(height: 28)
                        }
                    }
                }
            }

            Spacer()

            // 統計部分
            HStack(spacing: 12) {
                statItem(value: formattedDistance, label: "Distance")
                    .frame(maxWidth: .infinity, alignment: .leading)
                statItem(value: formattedDuration, label: "Time")
                    .frame(maxWidth: .infinity, alignment: .leading)
                statItem(value: "\(entry.runDays.count)", label: "Runs")
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding()
    }

    private var monthYearName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: entry.date)
    }

    private func statItem(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let runColor = Color("RunColor")
    private static let runDayTextColor = Color("RunDayTextColor")

    private func weekdayHeaderColor(index: Int) -> Color {
        let firstWeekdayIndex = calendar.firstWeekday - 1
        let actualWeekday = (index + firstWeekdayIndex) % 7
        switch actualWeekday {
        case 0: return .red   // 日曜
        case 6: return .blue  // 土曜
        default: return .secondary
        }
    }

    private func dayTextColor(weekday: Int, hasRun: Bool, isToday: Bool) -> Color {
        if hasRun {
            return Self.runDayTextColor
        }
        if isToday {
            return Self.runColor
        }
        // weekdayは表示位置(1-7)、実際の曜日に変換
        // calendar.firstWeekday: 1=日曜始まり, 2=月曜始まり
        let actualWeekday = ((weekday - 1 + calendar.firstWeekday - 1) % 7) + 1
        switch actualWeekday {
        case 1: return .red   // 日曜
        case 7: return .blue  // 土曜
        default: return .primary
        }
    }

    private enum CellSize {
        case medium, large

        var height: CGFloat {
            switch self {
            case .medium: return 16
            case .large: return 28
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .medium: return 10
            case .large: return 14
            }
        }

        var strokeWidth: CGFloat {
            switch self {
            case .medium: return 1
            case .large: return 1.5
            }
        }
    }

    private func dayCell(day: Int, weekday: Int, size: CellSize) -> some View {
        let hasRun = entry.runDays.contains(day)
        let isToday = day == today
        let fillOpacity = renderingMode == .fullColor ? 1.0 : 0.3

        return Text("\(day)")
            .font(.system(size: size.fontSize, weight: hasRun || isToday ? .semibold : .regular))
            .foregroundStyle(dayTextColor(weekday: weekday, hasRun: hasRun, isToday: isToday))
            .frame(width: size.height, height: size.height)
            .background {
                if hasRun {
                    Circle()
                        .fill(Self.runColor.opacity(fillOpacity))
                } else if isToday {
                    Circle()
                        .stroke(Self.runColor, lineWidth: size.strokeWidth)
                }
            }
    }
}

// MARK: - Widget Configuration

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Monthly Calendar")
        .description("Shows your running calendar for this month.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    CalendarWidget()
} timeline: {
    CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 10, 12, 15, 18, 20], totalDistance: 52.3, totalDuration: 3600 * 5 + 1800, useMetric: true)
}

#Preview("Medium", as: .systemMedium) {
    CalendarWidget()
} timeline: {
    CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 10, 12, 15, 18, 20], totalDistance: 52.3, totalDuration: 3600 * 5 + 1800, useMetric: true)
}

#Preview("Large", as: .systemLarge) {
    CalendarWidget()
} timeline: {
    CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 10, 12, 15, 18, 20], totalDistance: 52.3, totalDuration: 3600 * 5 + 1800, useMetric: true)
}
