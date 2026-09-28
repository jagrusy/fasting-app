import SwiftUI

public struct MealTimelineView: View {
    @ObservedObject var mealManager: MealManager
    @State private var mealToDelete: MealEntry?
    @State private var showDeleteConfirmation: Bool = false

    public init(mealManager: MealManager) {
        self.mealManager = mealManager
    }

    private var groupedMeals: [(date: Date, meals: [MealEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: mealManager.meals) { meal in
            calendar.startOfDay(for: meal.mealTime)
        }
        return grouped.map { (date: $0.key, meals: $0.value) }
            .sorted { $0.date > $1.date }
    }

    public var body: some View {
        if mealManager.meals.isEmpty {
            emptyState
        } else {
            List {
                ForEach(groupedMeals, id: \.date) { section in
                    Section(header: Text(sectionHeader(for: section.date))) {
                        ForEach(section.meals) { meal in
                            mealRow(meal)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        mealToDelete = meal
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("meal_timeline_list")
            .confirmationDialog(
                "Delete Meal?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Meal", role: .destructive) {
                    if let meal = mealToDelete {
                        try? mealManager.deleteMeal(id: meal.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes this meal and its photo.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundStyle(SolsticeColors.solarAmber)
                .padding(.top, 40)

            Text("No Meals Logged Yet")
                .font(.headline.weight(.semibold))

            Text("Take a photo or jot down what you eat to keep a simple food journal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .accessibilityIdentifier("meal_empty_state")
    }

    private func mealRow(_ meal: MealEntry) -> some View {
        HStack(spacing: 14) {
            if let thumb = meal.attachments.first?.thumbnailFilename ?? meal.attachments.first?.filename,
               let uiImage = mealManager.store.photoStorage.loadImage(filename: thumb) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 54, height: 54)
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mealTimeFormatted(meal.mealTime))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                if let notes = meal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("meal_row_\(meal.id.uuidString)")
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func mealTimeFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
