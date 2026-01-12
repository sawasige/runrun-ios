import SwiftUI

struct RunCalendarView: View {
    let year: Int
    let month: Int
    let records: [RunningRecord]
    @Binding var selectedRecord: RunningRecord?

    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 44

    private let calendar = Calendar.current
    private var weekdaySymbols: [String] {
        calendar.veryShortStandaloneWeekdaySymbols
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
    }

    private var firstWeekday: Int {
        calendar.component(.weekday, from: firstDayOfMonth) - 1 // 0-indexed (日曜=0)
    }

    /// 日付ごとの記録をマッピング
    private var recordsByDay: [Int: [RunningRecord]] {
        var dict: [Int: [RunningRecord]] = [:]
        for record in records {
            let day = calendar.component(.day, from: record.date)
            dict[day, default: []].append(record)
        }
        return dict
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var today: Int? {
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        // 今月の場合のみ今日の日付を返す
        guard year == currentYear && month == currentMonth else { return nil }
        return calendar.component(.day, from: now)
    }

    private struct CalendarCell: Identifiable {
        let id: Int
        let day: Int?
        let weekday: Int
    }

    private func makeCalendarCells() -> [CalendarCell] {
        var cells: [CalendarCell] = []

        // 月初の空白セル
        for i in 0..<firstWeekday {
            cells.append(CalendarCell(id: -i - 1, day: nil, weekday: i))
        }

        // 日付セル
        for day in 1...daysInMonth {
            let weekday = (firstWeekday + day - 1) % 7
            cells.append(CalendarCell(id: day, day: day, weekday: weekday))
        }

        return cells
    }

    var body: some View {
        VStack(spacing: 8) {
            // 曜日ヘッダー
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(index == 0 ? .red : (index == 6 ? .blue : .secondary))
                }
            }

            // カレンダーグリッド
            let calendarCells = makeCalendarCells()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(calendarCells) { cell in
                    if let day = cell.day {
                        dayCell(day: day, weekday: cell.weekday, isToday: day == today)
                    } else {
                        Color.clear
                            .frame(height: cellHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, weekday: Int, isToday: Bool) -> some View {
        let dayRecords = recordsByDay[day] ?? []
        let hasRun = !dayRecords.isEmpty
        let totalDistance = dayRecords.reduce(0) { $0 + $1.distanceInKilometers }

        Button {
            if let record = dayRecords.first {
                selectedRecord = record
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.caption)
                    .fontWeight(hasRun ? .bold : .regular)
                    .foregroundStyle(dayTextColor(weekday: weekday, hasRun: hasRun, isToday: isToday))

                if hasRun {
                    Text(String(format: "%.1f", totalDistance))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
            .background {
                if hasRun {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasRun)
    }

    private func dayTextColor(weekday: Int, hasRun: Bool, isToday: Bool) -> Color {
        if hasRun {
            return .white
        }
        if isToday {
            return .accentColor
        }
        switch weekday {
        case 0: return .red
        case 6: return .blue
        default: return .primary
        }
    }
}

#Preview {
    @Previewable @State var selectedRecord: RunningRecord?
    NavigationStack {
        List {
            Section {
                RunCalendarView(
                    year: 2025,
                    month: 1,
                    records: [
                        RunningRecord(date: Date(), distanceKm: 5.2, durationSeconds: 1800),
                        RunningRecord(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, distanceKm: 3.5, durationSeconds: 1200)
                    ],
                    selectedRecord: $selectedRecord
                )
            }
        }
    }
}
