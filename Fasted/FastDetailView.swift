import SwiftUI

public struct FastDetailView: View {
    @ObservedObject var fastManager: FastManager
    public let fast: Fast

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showDeleteConfirmation: Bool = false
    @State private var validationErrorMessage: String?
    @State private var showValidationError: Bool = false
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

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeaderCard
                timePickerCards
                deleteActionButton
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Fast Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveChanges)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("save_detail_button")
                }
            }
        }
        .alert("Invalid Fast Time", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationErrorMessage ?? "The selected dates are invalid.")
        }
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

    private var summaryHeaderCard: some View {
        VStack(spacing: 8) {
            Text(formatDuration(duration))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            HStack(spacing: 8) {
                Text(fast.protocolType ?? "16:8")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())

                if isGoalCompleted {
                    Label("Goal Met", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text("Ended Early")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var timePickerCards: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("START TIME")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Fast Started",
                    selection: $startDate,
                    in: ...min(endDate, Date()),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .onChange(of: startDate) { _ in hasChanges = true }
                .accessibilityIdentifier("edit_start_date_picker")
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
                    in: startDate...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .onChange(of: endDate) { _ in hasChanges = true }
                .accessibilityIdentifier("edit_end_date_picker")
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    private var deleteActionButton: some View {
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
        .padding(.top, 8)
        .accessibilityIdentifier("delete_fast_button")
    }

    private func saveChanges() {
        let validation = fastManager.validateInterval(
            startDate: startDate,
            endDate: endDate,
            excludingFastId: fast.id
        )

        if !validation.isValid {
            validationErrorMessage = validation.message
            showValidationError = true
            return
        }

        fastManager.updateCompletedFast(fast, startDate: startDate, endDate: endDate)
        hasChanges = false
        dismiss()
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
