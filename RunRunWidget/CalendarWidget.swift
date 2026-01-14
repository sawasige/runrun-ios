import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 12, 15], totalDistance: 42.5)
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
            totalDistance: data?.totalDistance ?? 0
        )
    }
}

// MARK: - Entry

struct CalendarEntry: TimelineEntry {
    let date: Date
    let runDays: Set<Int>
    let totalDistance: Double
}

// MARK: - Widget View

struct CalendarWidgetEntryView: View {
    var entry: CalendarProvider.Entry
    @Environment(\.widgetFamily) var family

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
        String(format: "%.1f km", entry.totalDistance)
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

    var body: some View {
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
                            dayCell(day: day, weekday: cell.weekday)
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

    private static let runColor = Color("RunColor")

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
            return .white
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

    private func dayCell(day: Int, weekday: Int) -> some View {
        let hasRun = entry.runDays.contains(day)
        let isToday = day == today

        return ZStack {
            if hasRun {
                Circle()
                    .fill(Self.runColor)
            } else if isToday {
                Circle()
                    .stroke(Self.runColor, lineWidth: 1)
            }

            Text("\(day)")
                .font(.system(size: 10, weight: hasRun || isToday ? .semibold : .regular))
                .foregroundStyle(dayTextColor(weekday: weekday, hasRun: hasRun, isToday: isToday))
        }
        .frame(height: 16)
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
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    CalendarWidget()
} timeline: {
    CalendarEntry(date: Date(), runDays: [1, 3, 5, 8, 10, 12, 15, 18, 20], totalDistance: 52.3)
}
