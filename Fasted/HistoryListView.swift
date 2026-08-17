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

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    private var groupedFasts: [(String, [Fast])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [String: [Fast]] = [:]
        var order: [String] = []

        for fast in completedFasts {
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
                List {
                    // Summary header stats
                    Section {
                        summaryCard
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    // Month Grouped Fasts
                    ForEach(groupedFasts, id: \.0) { month, fasts in
                        Section(header: Text(month).font(.subheadline.weight(.semibold))) {
                            ForEach(fasts) { fast in
                                FastRowView(fast: fast)
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
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL FASTS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(completedFasts.count)")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("total_fasts_count_label")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL TIME")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(formatTotalTime())
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("total_fasts_time_label")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("COMPLETION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(formatCompletionRate())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("total_fasts_rate_label")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func deleteFasts(at offsets: IndexSet, from list: [Fast]) {
        for index in offsets {
            let fast = list[index]
            fastManager.deleteFast(fast)
        }
    }

    private func formatTotalTime() -> String {
        let totalSeconds = completedFasts.reduce(0.0) { acc, fast in
            let start = fast.startDate ?? Date()
            let end = fast.endDate ?? start
            return acc + max(0, end.timeIntervalSince(start))
        }
        let hours = Int(totalSeconds / 3600)
        return "\(hours)h"
    }

    private func formatCompletionRate() -> String {
        guard !completedFasts.isEmpty else { return "0%" }
        let completedCount = completedFasts.filter { fast in
            let start = fast.startDate ?? Date()
            let end = fast.endDate ?? start
            return fast.isCompleted || (end.timeIntervalSince(start) >= fast.targetDuration)
        }.count

        let rate = Int((Double(completedCount) / Double(completedFasts.count)) * 100)
        return "\(rate)%"
    }
}
