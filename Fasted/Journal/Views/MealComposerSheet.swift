import PhotosUI
import SwiftUI

public struct MealComposerSheet: View {
    @ObservedObject var mealManager: MealManager
    @ObservedObject var fastManager: FastManager

    var initialMealTime: Date?
    var isPostFastInvitation: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var mealTime: Date
    @State private var notes: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false

    public init(
        mealManager: MealManager,
        fastManager: FastManager,
        initialMealTime: Date? = nil,
        isPostFastInvitation: Bool = false
    ) {
        self.mealManager = mealManager
        self.fastManager = fastManager
        self.initialMealTime = initialMealTime
        self.isPostFastInvitation = isPostFastInvitation
        _mealTime = State(initialValue: initialMealTime ?? mealManager.now())
    }

    public var body: some View {
        NavigationStack {
            Form {
                photoSection
                notesSection
                timeSection

                if isPostFastInvitation {
                    optOutSection
                }
            }
            .navigationTitle(isPostFastInvitation ? "Log Post-Fast Meal" : "Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPostFastInvitation ? "Not Now" : "Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(
                        isPostFastInvitation ? "meal_composer_not_now_button" : "meal_composer_cancel_button"
                    )
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeal()
                    }
                    .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil)
                    .accessibilityIdentifier("meal_composer_save_button")
                }
            }
            .alert("Couldn't Save Meal", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred while saving your meal.")
            }
        }
    }

    private var photoSection: some View {
        Section {
            if let selectedImage {
                VStack(spacing: 8) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(role: .destructive) {
                        self.selectedImage = nil
                        self.selectedPhotoItem = nil
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            } else {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(SolsticeColors.solarAmber)
                        Text("Add Photo")
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("meal_composer_photo_picker")
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                self.selectedImage = image
                            }
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section(header: Text("Note")) {
            TextField("What did you eat? (optional if photo attached)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("meal_composer_notes_input")
        }
    }

    private var timeSection: some View {
        Section(header: Text("Time")) {
            DatePicker("Meal Time", selection: $mealTime, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .accessibilityIdentifier("meal_composer_time_picker")
        }
    }

    private var optOutSection: some View {
        Section {
            Button(role: .destructive) {
                mealManager.declinePostFastPromptPermanently()
                dismiss()
            } label: {
                Text("Don't Ask Again")
                    .font(.footnote)
            }
            .accessibilityIdentifier("meal_composer_dont_ask_button")
        } footer: {
            Text("You can always log meals manually from the Journal tab.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func saveMeal() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = MealDraft(
            mealTime: mealTime,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            image: selectedImage
        )
        do {
            try mealManager.saveMeal(draft: draft, activeFast: fastManager.activeFast)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
