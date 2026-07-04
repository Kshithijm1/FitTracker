import SwiftUI
import SwiftData

extension FoodItem: Identifiable {}
extension SavedMeal: Identifiable {}

/// Target: 2 taps for a repeat meal (PLAN.md §3). Opens directly on
/// recents/frequents; typing merges in local results instantly, remote
/// results arrive async once Phase 3 wires providers into
/// `FoodSearchService.remoteProviders`.
struct LogMealSheet: View {
    var slot: MealSlot = .current()

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var searchText = ""
    @State private var results: [FoodItem] = []
    @State private var justLoggedItem: FoodItem?
    @State private var pendingQuantity: Double = 100
    @State private var showingFreeform = false
    @State private var showingBarcodeUnavailable = false

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty && !savedMeals.isEmpty {
                    Section("Saved meals") {
                        ForEach(savedMeals) { meal in
                            Button(meal.name) {
                                logSavedMeal(meal)
                            }
                        }
                    }
                }

                Section(searchText.isEmpty ? "Recents & frequents" : "Results") {
                    if results.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No recent foods yet" : "No matches",
                            systemImage: "fork.knife",
                            description: Text(
                                searchText.isEmpty
                                    ? "Logged foods appear here for instant re-logging."
                                    : "Try describing it freeform instead."
                            )
                        )
                    } else {
                        ForEach(results) { item in
                            FoodResultRow(
                                item: item,
                                isJustLogged: justLoggedItem?.id == item.id,
                                pendingQuantity: $pendingQuantity,
                                onTap: { logItem(item) },
                                onQuantityChange: { updateLoggedQuantity(item) }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .onChange(of: searchText) { _, newValue in
                refreshResults(query: newValue)
            }
            .onAppear { refreshResults(query: searchText) }
            .navigationTitle("Log \(slot.rawValue.capitalized)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Describe freeform", systemImage: "text.cursor") {
                            showingFreeform = true
                        }
                        Button("Scan barcode", systemImage: "barcode.viewfinder") {
                            showingBarcodeUnavailable = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFreeform) {
                FreeformDescribeView(slot: slot)
            }
            .alert("Barcode scanning arrives in Phase 3", isPresented: $showingBarcodeUnavailable) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func refreshResults(query: String) {
        results = (try? container.foodSearch.searchLocal(query: query)) ?? []
    }

    private func logItem(_ item: FoodItem) {
        let defaultQuantity = item.servings.first?.grams ?? 100
        let snapshot = MacroMath.scaleMacros(per100g: item.per100g, quantityG: defaultQuantity)
        let log = FoodLog(slot: slot, foodItemID: item.id, quantityG: defaultQuantity, macroSnapshot: snapshot)
        context.insert(log)
        item.recordUse()
        try? context.save()

        Haptics.light()
        pendingQuantity = defaultQuantity
        withAnimation { justLoggedItem = item }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if justLoggedItem?.id == item.id { justLoggedItem = nil } }
        }
    }

    private func updateLoggedQuantity(_ item: FoodItem) {
        var descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate<FoodLog> { $0.foodItemID == item.id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let log = try? context.fetch(descriptor).first else { return }
        log.quantityG = pendingQuantity
        log.macroSnapshot = MacroMath.scaleMacros(per100g: item.per100g, quantityG: pendingQuantity)
        log.markDirty()
        try? context.save()
    }

    private func logSavedMeal(_ meal: SavedMeal) {
        for savedItem in meal.items {
            guard let item = try? context.fetch(
                FetchDescriptor<FoodItem>(predicate: #Predicate<FoodItem> { $0.id == savedItem.foodItemID })
            ).first else { continue }
            let snapshot = MacroMath.scaleMacros(per100g: item.per100g, quantityG: savedItem.quantityG)
            context.insert(FoodLog(slot: slot, foodItemID: item.id, quantityG: savedItem.quantityG, macroSnapshot: snapshot))
            item.recordUse()
        }
        try? context.save()
        Haptics.light()
        dismiss()
    }
}
