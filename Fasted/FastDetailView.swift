import SwiftUI

public struct FastDetailView: View {
    @ObservedObject var fastManager: FastManager
    public let fast: Fast

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showDeleteConfirmation: Bool = false
    @State private var hasChanges: Bool = false

    public init(fastManager: FastManager, fast: Fast) {
        self.fastManager = fastManager
        self.fast = fast
        let start = fast.startDate ?? Date()
        let end = fast.endDate ?? start
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    private var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    private var isGoalCompleted: Bool {
        duration >= fast.targetDuration
    }

    private var progressRatio: Double {
        guard fast.targetDuration > 0 else { return 0.0 }
        return duration / fast.targetDuration
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Circular summary header
                ZStack {
                    ProgressRingView(
                        progress: min(1.0, progressRatio),
                        isFasting: true,
                        ringWidth: 16
                    )
                    .frame(width: 180, height: 180)

                    VStack(spacing: 4) {
                        Text(formatDuration(duration))
                            .font(.title2.weight(.bold))

                        Text("\(Int(progressRatio * 100))% of \(Int(fast.targetDuration / 3600))h")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isGoalCompleted ? .green : .secondary)

                        if isGoalCompleted {
                            Label("Goal Met", systemImage: "checkmark.seal.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.top, 16)

                // Editable Start & End Cards
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("START TIME")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Fast Started",
                            selection: $startDate,
                            in: ...endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: startDate) { _ in
                            hasChanges = true
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("END TIME")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Fast Ended",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: endDate) { _ in
                            hasChanges = true
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)

                // Delete Action Button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Fast", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .confirmationDialog(
                    "Delete Fast?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible,
                    actions: {
                        Button("Delete", role: .destructive) {
                            fastManager.deleteFast(fast)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    },
                    message: {
                        Text("This entry will be permanently removed from your fasting history.")
                    }
                )
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Fast Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        fastManager.updateCompletedFast(fast, startDate: startDate, endDate: endDate)
                        hasChanges = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
