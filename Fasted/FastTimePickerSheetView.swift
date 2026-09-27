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

/// Sheet for picking a custom fast length, offered from `FastTrackerView`'s Start menu's
/// "Custom…" item.
struct CustomFastSheetView: View {
    @State private var hours: Int
    let onStart: (Int) -> Void
    let onCancel: () -> Void

    init(initialHours: Int, onStart: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self._hours = State(initialValue: initialHours)
        self.onStart = onStart
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Fast Length", selection: $hours) {
                    ForEach(FastingProtocol.customHoursRange, id: \.self) { hour in
                        Text("\(hour) hours").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Button {
                    onStart(hours)
                } label: {
                    Text("Start \(hours)-Hour Fast")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("custom_fast_start_button")
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Custom Fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
