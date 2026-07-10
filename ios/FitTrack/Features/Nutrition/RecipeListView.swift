import SwiftUI
import SwiftData

/// Saved meals & recipes: log a serving in one tap, build a recipe from
/// ingredients, or import one from a link/caption with AI.
struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]

    @State private var showingBuilder = false
    @State private var showingImport = false

    private var visibleMeals: [SavedMeal] {
        meals.filter { $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingBuilder = true
                    } label: {
                        Label("Create a recipe", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.Color.accent)
                    }
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import from link or text", systemImage: "sparkles")
                            .foregroundStyle(Theme.Color.accent)
                    }
                }

                if !visibleMeals.isEmpty {
                    Section("My recipes & meals") {
                        ForEach(visibleMeals) { meal in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text(subtitle(for: meal))
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                                Spacer()
                                Button {
                                    logServing(of: meal)
                                } label: {
                                    Text("Log 1 serving")
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.onAccent)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.Color.accent, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                visibleMeals[index].markDeleted()
                            }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("Recipes & Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                RecipeBuilderView()
            }
            .sheet(isPresented: $showingImport) {
                RecipeImportView()
            }
        }
    }

    private func subtitle(for meal: SavedMeal) -> String {
        var parts = ["\(meal.items.count) ingredients"]
        if meal.servingsCount > 1 { parts.append("serves \(meal.servingsCount)") }
        if meal.origin == "import" { parts.append("imported") }
        return parts.joined(separator: " · ")
    }

    /// One serving = total ingredient macros ÷ servings.
    private func logServing(of meal: SavedMeal) {
        var total = MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0)
        var totalGrams = 0.0
        for ingredient in meal.items {
            let id = ingredient.foodItemID
            guard let food = try? context.fetch(
                FetchDescriptor<FoodItem>(predicate: #Predicate<FoodItem> { $0.id == id })
            ).first else { continue }
            let scaled = MacroMath.scaleMacros(per100g: food.per100g, quantityG: ingredient.quantityG)
            total = MacroSet(
                kcal: total.kcal + scaled.kcal,
                protein: total.protein + scaled.protein,
                carbs: total.carbs + scaled.carbs,
                fat: total.fat + scaled.fat
            )
            totalGrams += ingredient.quantityG
        }
        let servings = Double(max(meal.servingsCount, 1))
        let perServing = MacroSet(
            kcal: total.kcal / servings,
            protein: total.protein / servings,
            carbs: total.carbs / servings,
            fat: total.fat / servings
        )

        // A lightweight FoodItem stands in for "one serving of this recipe"
        // so the log row has a name and can be re-logged from My Foods.
        let servingGrams = max(totalGrams / servings, 1)
        let per100g = MacroMath.scaleMacros(per100g: perServing, quantityG: 100 * 100 / servingGrams)
        let mealName = meal.name // hoisted: #Predicate can't capture model properties
        let existing = try? context.fetch(
            FetchDescriptor<FoodItem>(predicate: #Predicate<FoodItem> { $0.name == mealName })
        ).first
        let foodItem = existing ?? FoodItem(
            name: meal.name,
            source: .custom,
            per100g: per100g,
            servings: [FoodServing(label: "1 serving", grams: servingGrams)]
        )
        if existing == nil { context.insert(foodItem) }

        context.insert(FoodLog(
            slot: .current(),
            foodItemID: foodItem.id,
            quantityG: servingGrams,
            macroSnapshot: perServing
        ))
        foodItem.recordUse()
        try? context.save()
        Haptics.light()
        dismiss()
    }
}
