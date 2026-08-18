import SwiftUI

public struct MedicalDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    generalDisclaimerCard
                    contraindicationsCard
                    warningSignsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Medical Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("disclaimer_done_button")
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Health & Safety Notice")
                    .font(.headline.weight(.bold))

                Text("Fasted is a habit tracker, not a medical device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var generalDisclaimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not Medical Advice", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            Text(
                "The content, timers, and metrics provided by Fasted are for informational and "
                + "habit-tracking purposes only. Fasted does not provide medical advice, diagnosis, "
                + "or treatment."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineSpacing(3)

            Text(
                "Always consult your physician or qualified healthcare provider before starting any "
                + "fasting protocol or changing your diet, especially if you have existing health conditions."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineSpacing(3)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var contraindicationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Who Should Avoid Fasting", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)

            Text("Fasting is not recommended for:")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            bulletItem("Individuals under 18 years of age")
            bulletItem("Individuals who are pregnant, nursing, or planning pregnancy")
            bulletItem("Anyone with a current or prior history of eating disorders")
            bulletItem("Individuals with Type 1 diabetes or taking insulin/blood-sugar medications")
            bulletItem("Individuals who are underweight or malnourished")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var warningSignsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("When to Break Your Fast", systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)

            Text(
                "Listen to your body. Break your fast immediately and eat or drink if you experience:"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            bulletItem("Severe dizziness, lightheadedness, or feeling faint")
            bulletItem("Extreme nausea, shakiness, or cold sweats")
            bulletItem("Irregular heartbeat, confusion, or severe weakness")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }
}
