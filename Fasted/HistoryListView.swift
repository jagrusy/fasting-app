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

    @State private var currentMonthDate: Date = Date()

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    private var streakInfo: StreakInfo {
        StreakCalculator.calculate(from: Array(completedFasts))
    }

    private var monthFasts: [Fast] {
        let calendar = Calendar.current
        return completedFasts.filter { fast in
            guard let start = fast.startDate else { return false }
            return calendar.isDate(start, equalTo: currentMonthDate, toGranularity: .month)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonthDate)
    }

    public var body: some View {
        historyContentList
    }

    private var historyContentList: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    StreakSummaryCardsView(streakInfo: streakInfo)
                    CalendarHeatmapView(
                        fasts: Array(completedFasts),
                        currentMonthDate: $currentMonthDate
                    )
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if completedFasts.isEmpty {
                emptyHistorySection
            } else if monthFasts.isEmpty {
                emptyMonthSection
            } else {
                monthFastsSection
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("history_fast_list")
    }

    private var emptyHistorySection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No Completed Fasts Yet")
                    .font(.headline.weight(.semibold))
                Text("Start and complete a fast to build your streak and fill your calendar heatmap.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private var emptyMonthSection: some View {
        Section(header: Text(monthTitle).font(.subheadline.weight(.semibold))) {
            VStack(spacing: 6) {
                Text("No fasts recorded in \(monthTitle).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var monthFastsSection: some View {
        Section(header: Text(monthTitle).font(.subheadline.weight(.semibold))) {
            ForEach(monthFasts) { fast in
                NavigationLink {
                    FastDetailView(fastManager: fastManager, fast: fast)
                } label: {
                    FastRowView(fast: fast)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            fastManager.deleteFast(fast)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                deleteFasts(at: indexSet, from: monthFasts)
            }
        }
    }

    private func deleteFasts(at offsets: IndexSet, from list: [Fast]) {
        for index in offsets {
            let fast = list[index]
            fastManager.deleteFast(fast)
        }
    }
}
