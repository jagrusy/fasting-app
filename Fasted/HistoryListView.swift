import SwiftUI
import CoreData

public struct HistoryListView: View {
    @ObservedObject var fastManager: FastManager

    @FetchRequest(
        entity: Fast.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Fast.startDate, ascending: false)],
        predicate: NSPredicate(format: "endDate != nil"),
        animation: .default
    )
    private var completedFasts: FetchedResults<Fast>

    @State private var selectedDate: Date?

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    private var streakInfo: StreakInfo {
        StreakCalculator.calculate(from: Array(completedFasts))
    }

    private var filteredFasts: [Fast] {
        guard let selected = selectedDate else { return Array(completedFasts) }
        let calendar = Calendar.current
        return completedFasts.filter { fast in
            guard let start = fast.startDate else { return false }
            return calendar.isDate(start, inSameDayAs: selected)
        }
    }

    private var groupedFasts: [(String, [Fast])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [String: [Fast]] = [:]
        var order: [String] = []

        for fast in filteredFasts {
            let key = formatter.string(from: fast.startDate ?? Date())
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(fast)
        }

        return order.map { ($0, groups[$0] ?? []) }
    }

    public var body: some View {
        Group {
            if completedFasts.isEmpty {
                EmptyHistoryView()
            } else {
                historyContentList
            }
        }
    }

    private var historyContentList: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    StreakSummaryCardsView(streakInfo: streakInfo)
                    CalendarHeatmapView(fasts: Array(completedFasts), selectedDate: $selectedDate)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if selectedDate != nil {
                filterHeaderSection
            }

            ForEach(groupedFasts, id: \.0) { month, fasts in
                Section(header: Text(selectedDate != nil ? "Fasts for Selected Day" : month)
                    .font(.subheadline.weight(.semibold))) {
                    ForEach(fasts) { fast in
                        NavigationLink {
                            FastDetailView(fastManager: fastManager, fast: fast)
                        } label: {
                            FastRowView(fast: fast)
                        }
                    }
                    .onDelete { indexSet in
                        deleteFasts(at: indexSet, from: fasts)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("history_fast_list")
    }

    @ViewBuilder
    private var filterHeaderSection: some View {
        if let selected = selectedDate {
            Section {
                HStack {
                    Text("Filtered: \(formattedDate(selected))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Show All") {
                        withAnimation { selectedDate = nil }
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("clear_filter_button")
                }
            }
        }
    }

    private func deleteFasts(at offsets: IndexSet, from list: [Fast]) {
        for index in offsets {
            let fast = list[index]
            fastManager.deleteFast(fast)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
