import SwiftUI

public struct CalendarHeatmapView: View {
    public let fasts: [Fast]
    @Binding public var selectedDate: Date?
    @State private var currentMonthDate: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    public init(fasts: [Fast], selectedDate: Binding<Date?>) {
        self.fasts = fasts
        self._selectedDate = selectedDate
    }

    private var canGoForward: Bool {
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let displayedMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonthDate)
        ) ?? currentMonthDate
        return displayedMonth < currentMonth
    }

    private var canGoBackward: Bool {
        let minMonth = calendar.date(byAdding: .month, value: -24, to: Date()) ?? Date()
        let minMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: minMonth)
        ) ?? minMonth
        let displayedMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonthDate)
        ) ?? currentMonthDate
        return displayedMonth > minMonthStart
    }

    public var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            daysGrid
            legendView
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 40 {
                        changeMonth(by: -1)
                    }
                }
        )
        .accessibilityIdentifier("calendar_heatmap_view")
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canGoBackward ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(!canGoBackward)
            .accessibilityIdentifier("calendar_prev_month_button")

            Spacer()

            Text(monthYearString(from: currentMonthDate))
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier("calendar_month_title")

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(!canGoForward)
            .accessibilityIdentifier("calendar_next_month_button")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysInMonth(for: currentMonthDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(0..<days.count, id: \.self) { index in
                if let date = days[index] {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let status = StreakCalculator.fastStatus(for: date, in: fasts, calendar: calendar)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            if isSelected {
                selectedDate = nil
            } else {
                selectedDate = date
            }
        } label: {
            ZStack {
                cellBackground(status: status, isSelected: isSelected)

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isToday || isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(cellTextColor(status: status, isSelected: isSelected))

                if isToday && !isSelected {
                    Circle()
                        .stroke(Color.primary, lineWidth: 1.5)
                        .padding(2)
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar_day_\(dayNumber)")
    }

    private func cellBackground(status: DayFastStatus, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(cellFillColor(status: status))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
    }

    private func cellFillColor(status: DayFastStatus) -> Color {
        switch status {
        case .none:
            return Color(.tertiarySystemBackground)
        case .partial:
            return Color.orange.opacity(0.35)
        case .goalMet:
            return Color.green
        }
    }

    private func cellTextColor(status: DayFastStatus, isSelected: Bool) -> Color {
        switch status {
        case .goalMet:
            return Color.white
        case .partial:
            return Color.orange
        case .none:
            return isSelected ? Color.primary : Color.secondary
        }
    }

    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: Color(.tertiarySystemBackground), title: "None")
            legendItem(color: Color.orange.opacity(0.35), title: "Partial")
            legendItem(color: Color.green, title: "Goal Met")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }

    private func changeMonth(by value: Int) {
        if value > 0 && !canGoForward { return }
        if value < 0 && !canGoBackward { return }
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonthDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentMonthDate = newDate
            }
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth(for date: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1=Sun
        let leadingSpaces = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(dayDate)
            }
        }
        return days
    }
}
