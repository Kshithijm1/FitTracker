import SwiftUI
import SwiftData

/// Freeform "2 eggs and toast" entry. Phase 1 stores a manual estimate the
/// user edits themselves; Phase 3 swaps `estimate(from:)` for a call to
/// `POST /v1/nutrition/estimate` (Claude Haiku) and shows a confidence tag
/// (PLAN.md §1/§3).
struct FreeformDescribeView: View {
    let slot: MealSlot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var kcal: Double = 300
    @State private var protein: Double = 15
    @State private var carbs: Double = 30
    @State private var fat: Double = 10

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("e.g. 2 eggs and toast", text: $description, axis: .vertical)
                }

                Section("Estimated macros") {
                    Text("AI estimation arrives in Phase 3 — enter your best guess for now.")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Stepper("Calories: \(Int(kcal))", value: $kcal, in: 0...2000, step: 10)
                    Stepper("Protein: \(Int(protein))g", value: $protein, in: 0...200, step: 1)
                    Stepper("Carbs: \(Int(carbs))g", value: $carbs, in: 0...300, step: 1)
                    Stepper("Fat: \(Int(fat))g", value: $fat, in: 0...150, step: 1)
                }
            }
            .navigationTitle("Describe Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { logEstimate() }
                        .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func logEstimate() {
        let macros = MacroSet(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        let foodItem = FoodItem(
            name: description,
            source: .estimate,
            per100g: macros // stored as the whole-portion estimate; quantityG is fixed at 100
        )
        context.insert(foodItem)
        context.insert(FoodLog(slot: slot, foodItemID: foodItem.id, quantityG: 100, macroSnapshot: macros))
        try? context.save()
        Haptics.light()
        dismiss()
    }
}
