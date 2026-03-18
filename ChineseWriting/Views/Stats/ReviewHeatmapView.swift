import SwiftUI

/// A GitHub-style contribution heatmap showing daily review activity
/// over the past several weeks.
struct ReviewHeatmapView: View {
    let reviewCounts: [Date: Int]
    var weeks: Int = 12

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    var body: some View {
        let grid = buildGrid()

        VStack(alignment: .leading, spacing: 8) {
            // Month labels
            HStack(spacing: 0) {
                ForEach(monthLabels(grid: grid), id: \.offset) { label in
                    Text(label.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: CGFloat(label.span) * (cellSize + cellSpacing), alignment: .leading)
                }
            }
            .padding(.leading, 20)

            HStack(alignment: .top, spacing: 0) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { day in
                        if day == 1 || day == 3 || day == 5 {
                            Text(shortDayName(day))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: cellSize)
                        } else {
                            Color.clear
                                .frame(width: 18, height: cellSize)
                        }
                    }
                }

                // Grid cells
                HStack(spacing: cellSpacing) {
                    ForEach(0..<grid.count, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<grid[col].count, id: \.self) { row in
                                let entry = grid[col][row]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForCount(entry.count))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }

            // Legend (hidden from VoiceOver since we provide a summary)
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                ForEach([0, 1, 5, 10, 20], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForCount(level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heatmapSummary)
    }

    /// Text summary of review activity for VoiceOver users.
    private var heatmapSummary: String {
        let totalReviews = reviewCounts.values.reduce(0, +)
        let activeDays = reviewCounts.values.filter { $0 > 0 }.count
        return "Review activity: \(totalReviews) reviews over \(activeDays) active days in the last \(weeks) weeks"
    }

    // MARK: - Grid Building

    private struct DayEntry {
        let date: Date?
        let count: Int
    }

    /// Build a column-major grid: each column is a week (Sun–Sat),
    /// going back `weeks` weeks from today.
    private func buildGrid() -> [[DayEntry]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat

        // Total days to show
        let totalDays = weeks * 7
        guard let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }

        // Build flat list of days
        var days: [DayEntry] = []
        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let count = reviewCounts[dayStart] ?? 0
            days.append(DayEntry(date: dayStart, count: count))
        }

        // Pad the start so the first column begins on Sunday
        let startWeekday = calendar.component(.weekday, from: startDate) // 1=Sun
        let padBefore = startWeekday - 1
        let paddedDays = Array(repeating: DayEntry(date: nil, count: 0), count: padBefore) + days

        // Pad end to fill the last week
        let remainder = paddedDays.count % 7
        let padAfter = remainder == 0 ? 0 : 7 - remainder
        // Only include rows up to today's weekday in the last column
        let allDays = paddedDays + Array(repeating: DayEntry(date: nil, count: 0), count: padAfter)

        // Split into columns of 7
        var grid: [[DayEntry]] = []
        for col in stride(from: 0, to: allDays.count, by: 7) {
            let end = min(col + 7, allDays.count)
            grid.append(Array(allDays[col..<end]))
        }

        return grid
    }

    // MARK: - Colors

    private func colorForCount(_ count: Int) -> Color {
        if count == 0 { return Color(.systemGray5) }
        if count <= 2 { return Color.green.opacity(0.3) }
        if count <= 5 { return Color.green.opacity(0.5) }
        if count <= 10 { return Color.green.opacity(0.7) }
        return Color.green.opacity(0.9)
    }

    // MARK: - Labels

    private func shortDayName(_ weekdayIndex: Int) -> String {
        // 0=Sun, 1=Mon, ..., 6=Sat
        let names = ["S", "M", "T", "W", "T", "F", "S"]
        return names[weekdayIndex]
    }

    private struct MonthLabel: Identifiable {
        let offset: Int
        let name: String
        let span: Int
        var id: Int { offset }
    }

    private func monthLabels(grid: [[DayEntry]]) -> [MonthLabel] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [MonthLabel] = []
        var lastMonth = -1

        for (colIndex, column) in grid.enumerated() {
            // Use the first real date in the column
            guard let date = column.first(where: { $0.date != nil })?.date else { continue }
            let month = Calendar.current.component(.month, from: date)
            if month != lastMonth {
                labels.append(MonthLabel(offset: colIndex, name: formatter.string(from: date), span: 1))
                lastMonth = month
            } else if let last = labels.last {
                labels[labels.count - 1] = MonthLabel(offset: last.offset, name: last.name, span: last.span + 1)
            }
        }

        return labels
    }
}
