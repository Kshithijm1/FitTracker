import SwiftUI
import SwiftData

extension FoodItem: Identifiable {}
extension SavedMeal: Identifiable {}

/// Target: 2 taps for a repeat meal (PLAN.md §3). Opens directly on
/// recents/frequents; typing shows local results instantly, remote OFF/USDA
/// results merge in async (skeleton shimmer while in flight — the only
/// loading state in the app, per PLAN.md §3).
struct LogMealSheet: View {
    var slot: MealSlot = .current()

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var searchText = ""
    @State private var results: [FoodItem] = []
    @State private var isSearchingRemote = false
    @State private var justLoggedItem: FoodItem?
    @State private var pendingQuantity: Double = 100
    @State private var showingFreeform = false
    @State private var showingBarcodeScanner = false
    @State private var barcodeLookupError: String?

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
                    if results.isEmpty && !isSearchingRemote {
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
                        if isSearchingRemote {
                            RemoteSearchSkeletonRow()
                        }
                    }
                }

                if let barcodeLookupError {
                    Text(barcodeLookupError)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.error)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .onAppear { refreshLocalResults(query: searchText) }
            .task(id: searchText) {
                refreshLocalResults(query: searchText)
                await mergeInRemoteResults(query: searchText)
            }
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
                            showingBarcodeScanner = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add food")
                }
            }
            .sheet(isPresented: $showingFreeform) {
                FreeformDescribeView(slot: slot)
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { barcode in
                    Task { await handleScannedBarcode(barcode) }
                }
            }
        }
    }

    private func refreshLocalResults(query: String) {
        results = (try? container.foodSearch.searchLocal(query: query)) ?? []
    }

    private func mergeInRemoteResults(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingRemote = true
        defer { isSearchingRemote = false }

        let remoteResults = await container.foodSearch.searchRemote(query: query)
        guard !Task.isCancelled, searchText == query else { return }

        let existingIDs = Set(results.map(\.id))
        results.append(contentsOf: remoteResults.filter { !existingIDs.contains($0.id) })
    }

    private func handleScannedBarcode(_ barcode: String) async {
        showingBarcodeScanner = false
        do {
            guard let item = try await container.foodSearch.lookupBarcode(barcode) else {
                barcodeLookupError = "No product found for that barcode."
                return
            }
            barcodeLookupError = nil
            logItem(item)
        } catch {
            barcodeLookupError = "Barcode lookup failed. Check your connection and try again."
        }
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
        withAnimation(Theme.Motion.quickSpring(reduceMotion: reduceMotion)) { justLoggedItem = item }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(Theme.Motion.quickSpring(reduceMotion: reduceMotion)) {
                if justLoggedItem?.id == item.id { justLoggedItem = nil }
            }
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

/// Skeleton shimmer while remote OFF/USDA results are in flight — the only
/// loading state in the app (everything else renders local-first, PLAN.md §3).
private struct RemoteSearchSkeletonRow: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 4).frame(width: 160, height: 14)
            RoundedRectangle(cornerRadius: 4).frame(width: 90, height: 12)
        }
        .foregroundStyle(Theme.Color.surface2)
        .opacity(isPulsing ? 0.4 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
