import SwiftUI

public struct JournalTabView: View {
    @ObservedObject var fastManager: FastManager
    @ObservedObject var mealManager: MealManager
    var onSettingsTapped: (() -> Void)?

    @State private var selectedSegment: JournalSegment = .meals
    @State private var showComposer: Bool = false

    public enum JournalSegment: String, CaseIterable, Identifiable {
        case meals = "Meals"
        case fasts = "Fasts"

        public var id: String { rawValue }
    }

    public init(
        fastManager: FastManager,
        mealManager: MealManager,
        onSettingsTapped: (() -> Void)? = nil
    ) {
        self.fastManager = fastManager
        self.mealManager = mealManager
        self.onSettingsTapped = onSettingsTapped
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Journal View", selection: $selectedSegment) {
                    ForEach(JournalSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("journal_tab_segmented_picker")

                Group {
                    switch selectedSegment {
                    case .meals:
                        MealTimelineView(mealManager: mealManager)
                    case .fasts:
                        HistoryListView(fastManager: fastManager)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SolsticeColors.solarAmber)
                    }
                    .accessibilityIdentifier("journal_log_meal_button")
                }

                if let onSettingsTapped {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onSettingsTapped) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color.primary)
                        }
                        .accessibilityIdentifier("journal_settings_button")
                    }
                }
            }
            .sheet(isPresented: $showComposer) {
                MealComposerSheet(
                    mealManager: mealManager,
                    fastManager: fastManager,
                    isPostFastInvitation: false
                )
            }
        }
    }
}
