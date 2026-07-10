import SwiftUI
import SwiftData

/// Build a recipe by hand: name it, say how many it feeds, add ingredients
/// (full food search) with amounts in any unit. Saves as a `SavedMeal`
/// whose per-serving macros come from the summed ingredients.
struct RecipeBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var servings = 2
    @State private var ingredients: [Ingredient] = []
    @State private var showingFoodPicker = false

    struct Ingredient: Identifiable {
        let id = UUID()
        var foodItem: FoodItem
        var quantity: Double
        var unit: FoodUnit

        var grams: Double {
            unit.grams(quantity: quantity, servingGrams: foodItem.servings.first?.grams ?? 100)
        }
    }

    private var totalMacros: MacroSet {
        ingredients.reduce(MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0)) { acc, ingredient in
            let scaled = MacroMath.scaleMacros(per100g: ingredient.foodItem.per100g, quantityG: ingredient.grams)
            return MacroSet(
                kcal: acc.kcal + scaled.kcal,
                protein: acc.protein + scaled.protein,
                carbs: acc.carbs + scaled.carbs,
                fat: acc.fat + scaled.fat
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recipe name (e.g. Chicken Stir-Fry)", text: $name)
                    Stepper("Feeds \(servings) \(servings == 1 ? "person" : "people")", value: $servings, in: 1...20)
                }

                Section("Ingredients") {
                    ForEach($ingredients) { $ingredient in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(ingredient.foodItem.name)
                                .font(Theme.Font.bodyEmphasized17)
                            HStack {
                                TextField("Amount", value: $ingredient.quantity, format: .number.precision(.fractionLength(0...2)))
                                    .keyboardType(.decimalPad)
                                    .frame(width: 70)
                                Picker("Unit", selection: $ingredient.unit) {
                                    ForEach(FoodUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                Spacer()
                                Text("\(Int(MacroMath.scaleMacros(per100g: ingredient.foodItem.per100g, quantityG: ingredient.grams).kcal)) kcal")
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }

                    Button {
                        showingFoodPicker = true
                    } label: {
                        Label("Add ingredient", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.Color.accent)
                    }
                }

                if !ingredients.isEmpty {
                    Section("Per serving (\(servings) total)") {
                        let perServing = servings > 0 ? totalMacros.kcal / Double(servings) : 0
                        LabeledContent("Calories", value: "\(Int(perServing)) kcal")
                        LabeledContent("Protein", value: "\(Int(totalMacros.protein / Double(max(servings, 1))))g")
                        LabeledContent("Carbs", value: "\(Int(totalMacros.carbs / Double(max(servings, 1))))g")
                        LabeledContent("Fat", value: "\(Int(totalMacros.fat / Double(max(servings, 1))))g")
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $showingFoodPicker) {
                IngredientSearchSheet { food in
                    ingredients.append(Ingredient(foodItem: food, quantity: 100, unit: .grams))
                }
            }
        }
    }

    private func save() {
        let meal = SavedMeal(name: name.trimmingCharacters(in: .whitespaces), servingsCount: servings, origin: "recipe")
        for ingredient in ingredients {
            meal.items.append(SavedMealItem(foodItemID: ingredient.foodItem.id, quantityG: ingredient.grams))
        }
        context.insert(meal)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

/// Slim wrapper around the food search used when picking recipe
/// ingredients (local + OFF/USDA remote).
struct IngredientSearchSheet: View {
    let onPick: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var searchText = ""
    @State private var results: [FoodItem] = []
    @State private var isSearchingRemote = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { item in
                    Button {
                        onPick(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).foregroundStyle(Theme.Color.textPrimary)
                            Text("\(Int(item.per100g.kcal)) kcal/100g\(item.brand.map { " · \($0)" } ?? "")")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
                if isSearchingRemote {
                    HStack {
                        ProgressView()
                        Text("Searching food databases…")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .task(id: searchText) {
                results = (try? container.foodSearch.searchLocal(query: searchText)) ?? []
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                isSearchingRemote = true
                defer { isSearchingRemote = false }
                let remote = await container.foodSearch.searchRemote(query: searchText)
                guard !Task.isCancelled else { return }
                let existing = Set(results.map(\.id))
                results.append(contentsOf: remote.filter { !existing.contains($0.id) })
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
