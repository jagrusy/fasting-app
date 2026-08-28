import SwiftUI

struct EndFastButtonView: View {
    let goalReached: Bool
    let onComplete: () -> Void
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var showStopConfirmation = false

    var body: some View {
        let buttonTitle = goalReached ? "Complete Fast" : "End Fast"

        Button {
            if goalReached {
                onComplete()
            } else {
                showStopConfirmation = true
            }
        } label: {
            Text(buttonTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(goalReached ? Color.green : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityIdentifier("end_fast_button")
        .padding(.horizontal, 24)
        .confirmationDialog(
            "End Fast Early?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible,
            actions: {
                Button("Save Fast", action: onSave)
                Button("Discard Fast", role: .destructive, action: onDiscard)
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("You haven't reached your goal yet. Save this as a shorter fast in your history," +
                     " or discard it as if it never happened.")
            }
        )
    }
}
