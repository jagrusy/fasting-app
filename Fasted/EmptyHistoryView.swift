import SwiftUI

public struct EmptyHistoryView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
            }
            .padding(.top, 40)

            VStack(spacing: 8) {
                Text("No Fasts Yet")
                    .font(.title2.weight(.bold))

                Text("Complete your first fast to start building your history, streaks, and trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empty_history_view")
    }
}
