import SwiftUI
import SwiftData

/// Freeform "2 eggs and toast" entry. When signed in, "Get AI estimate"
/// calls `POST /v1/nutrition/estimate` (Claude Haiku) and pre-fills the
/// macros with a confidence tag, editable before logging; manual entry is
/// always available as a fallback (offline, signed out, or request failure)
/// (PLAN.md §1/§3).
struct FreeformDescribeView: View {
    let slot: MealSlot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var description = ""
    @State private var kcal: Double = 300
    @State private var protein: Double = 15
    @State private var carbs: Double = 30
    @State private var fat: Double = 10
    @State private var confidence: EstimateConfidence?
    @State private var isEstimating = false
    @State private var estimateError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you eat?") {
                    TextField("e.g. 2 eggs and toast", text: $description, axis: .vertical)

                    if container.auth.isSignedIn {
                        Button {
                            Task { await fetchEstimate() }
                        } label: {
                            if isEstimating {
                                Label("Estimating…", systemImage: "sparkles")
                            } else {
                                Label("Get AI estimate", systemImage: "sparkles")
                            }
                        }
                        .disabled(isEstimating || description.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Estimated macros") {
                    if let confidence {
                        Label("AI estimate · \(confidence.rawValue) confidence", systemImage: "sparkles")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.accent)
                    } else if let estimateError {
                        Text(estimateError)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.error)
                    } else {
                        Text(
                            container.auth.isSignedIn
                                ? "Tap \"Get AI estimate\", or enter your best guess."
                                : "Sign in (Profile tab) to enable AI estimates, or enter your best guess."
                        )
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                    }

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

    private func fetchEstimate() async {
        isEstimating = true
        estimateError = nil
        defer { isEstimating = false }
        do {
            let result = try await NutritionEstimateService.estimate(description: description)
            kcal = result.calories
            protein = result.protein
            carbs = result.carbs
            fat = result.fat
            confidence = result.confidence
            Haptics.light()
        } catch {
            confidence = nil
            estimateError = "Couldn't get an AI estimate — enter your best guess instead."
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
