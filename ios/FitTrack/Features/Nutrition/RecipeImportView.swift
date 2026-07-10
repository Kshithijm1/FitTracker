import SwiftUI
import SwiftData

/// Paste a link (recipe site, TikTok/Instagram share link) or the caption
/// text itself — AI extracts the ingredients, amounts, and servings into
/// an editable recipe. Share-sheet → FitTrack lands here too via the URL
/// the system hands over.
struct RecipeImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var source = ""
    @State private var isImporting = false
    @State private var errorText: String?
    @State private var imported: ImportedRecipe?
    @State private var editedName = ""
    @State private var editedServings = 4

    var body: some View {
        NavigationStack {
            Form {
                if imported == nil {
                    Section("Link or recipe text") {
                        TextField(
                            "Paste a URL, or the recipe/caption text…",
                            text: $source,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            Task { await runImport() }
                        } label: {
                            if isImporting {
                                Label("Reading the recipe…", systemImage: "sparkles")
                            } else {
                                Label("Import with AI", systemImage: "sparkles")
                            }
                        }
                        .disabled(isImporting || source.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)

                        if !container.auth.isSignedIn {
                            Text("Recipe import needs a signed-in account (the AI runs server-side).")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        if let errorText {
                            Text(errorText)
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.error)
                        }
                    }
                }

                if let imported {
                    Section("Recipe") {
                        TextField("Name", text: $editedName)
                        Stepper("Feeds \(editedServings)", value: $editedServings, in: 1...20)
                    }
                    Section("Ingredients (\(imported.ingredients.count))") {
                        ForEach(imported.ingredients) { ingredient in
                            HStack {
                                Text(ingredient.name)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Spacer()
                                Text("\(Int(ingredient.grams))g")
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                    }
                    Section {
                        Button("Start over") {
                            self.imported = nil
                            source = ""
                        }
                    }
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if imported != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func runImport() async {
        isImporting = true
        errorText = nil
        defer { isImporting = false }
        do {
            let recipe = try await container.ai.importRecipe(from: source.trimmingCharacters(in: .whitespacesAndNewlines))
            guard !recipe.ingredients.isEmpty else {
                errorText = "Couldn't find ingredients in that — try pasting the recipe text directly."
                return
            }
            imported = recipe
            editedName = recipe.name
            editedServings = max(recipe.servings, 1)
            Haptics.success()
        } catch AIServiceError.unavailable {
            errorText = "Sign in (Profile tab) to import recipes."
        } catch let APIError.server(_, message) {
            errorText = message
        } catch {
            errorText = "Import failed — check the link or paste the recipe text instead."
        }
    }

    private func save() {
        guard let imported else { return }
        let meal = SavedMeal(
            name: editedName.trimmingCharacters(in: .whitespaces),
            servingsCount: editedServings,
            origin: "import"
        )
        for ingredient in imported.ingredients {
            // Each ingredient becomes a reusable FoodItem with AI-estimated
            // per-100g macros (deduped by name against earlier imports).
            let ingredientName = ingredient.name
            let existing = try? context.fetch(
                FetchDescriptor<FoodItem>(predicate: #Predicate<FoodItem> { $0.name == ingredientName })
            ).first
            let food = existing ?? FoodItem(
                name: ingredient.name,
                source: .estimate,
                per100g: MacroSet(
                    kcal: ingredient.kcalPer100g,
                    protein: ingredient.proteinPer100g,
                    carbs: ingredient.carbsPer100g,
                    fat: ingredient.fatPer100g
                )
            )
            if existing == nil { context.insert(food) }
            meal.items.append(SavedMealItem(foodItemID: food.id, quantityG: ingredient.grams))
        }
        context.insert(meal)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
