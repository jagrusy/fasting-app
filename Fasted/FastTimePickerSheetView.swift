import SwiftUI

struct FastTimePickerSheetView: View {
    @Binding var tempTime: Date
    let onCancel: () -> Void
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Start Time",
                    selection: $tempTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()

                Spacer()
            }
            .navigationTitle("Adjust Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(tempTime) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
