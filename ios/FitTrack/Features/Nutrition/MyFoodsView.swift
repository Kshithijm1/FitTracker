import SwiftUI
import SwiftData

/// Everything the user has ever logged, most-recent first, each with its
/// last-used portion — one tap re-logs exactly what you had before.
struct MyFoodsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<FoodItem> { $0.lastUsedAt != nil },
        sort: \FoodItem.lastUsedAt,
        order: .reverse
    ) private var usedFoods: [FoodItem]

    @State private var searchText = ""

    private var filtered: [FoodItem] {
        let visible = usedFoods.filter { $0.deletedAt == nil }
        guard !searchText.isEmpty else { return visible }
        return visible.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if usedFoods.isEmpty {
                    ContentUnavailableView(
                        "No foods yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Every food you log is remembered here with the portion you used.")
                    )
                } else {
                    List(filtered) { item in
                        Button {
                            relog(item)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                        .lineLimit(1)
                                    Text(detailLine(for: item))
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.Color.accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search my foods")
                }
            }
            .navigationTitle("My Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func lastQuantity(for item: FoodItem) -> Double {
        let id = item.id
        var descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate<FoodLog> { $0.foodItemID == id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.quantityG ?? 100
    }

    private func detailLine(for item: FoodItem) -> String {
        let grams = lastQuantity(for: item)
        let kcal = Int(MacroMath.scaleMacros(per100g: item.per100g, quantityG: grams).kcal)
        var line = "Last: \(Int(grams))g · \(kcal) kcal"
        if let brand = item.brand { line = "\(brand) · " + line }
        return line
    }

    private func relog(_ item: FoodItem) {
        let grams = lastQuantity(for: item)
        let snapshot = MacroMath.scaleMacros(per100g: item.per100g, quantityG: grams)
        context.insert(FoodLog(slot: .current(), foodItemID: item.id, quantityG: grams, macroSnapshot: snapshot))
        item.recordUse()
        try? context.save()
        Haptics.light()
        dismiss()
    }
}
