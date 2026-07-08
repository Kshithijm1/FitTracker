import SwiftUI
import SwiftData

struct NutritionHomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var todayLogs: [FoodLog]
    @State private var showingLogSheet = false
    @State private var foodNamesByID: [UUID: String] = [:]

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _todayLogs = Query(
            filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\.date)]
        )
    }

    private func foodName(for id: UUID) -> String {
        foodNamesByID[id] ?? "Food"
    }

    /// Looks up only the handful of `FoodItem`s referenced by today's logs
    /// — not the whole (potentially large, remote-search-cached) table.
    private func refreshFoodNames() {
        let ids = Set(todayLogs.map(\.foodItemID))
        guard !ids.isEmpty else {
            foodNamesByID = [:]
            return
        }
        let items = (try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        foodNamesByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    let logsForSlot = todayLogs.filter { $0.slot == slot }
                    if !logsForSlot.isEmpty {
                        Section(slot.rawValue.capitalized) {
                            ForEach(logsForSlot) { log in
                                HStack {
                                    Text(foodName(for: log.foodItemID))
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                    Text("\(Int(log.macroSnapshot.kcal)) kcal")
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                            }
                            .onDelete { offsets in
                                delete(logsForSlot, at: offsets)
                            }
                        }
                    }
                }

                if todayLogs.isEmpty {
                    ContentUnavailableView(
                        "Nothing logged yet today",
                        systemImage: "fork.knife",
                        description: Text("Tap + to log your first meal.")
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log a meal")
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogMealSheet()
            }
            .onAppear { refreshFoodNames() }
            .onChange(of: todayLogs.count) { _, _ in refreshFoodNames() }
        }
    }

    private func delete(_ logs: [FoodLog], at offsets: IndexSet) {
        for index in offsets {
            context.delete(logs[index])
        }
        try? context.save()
    }
}

extension FoodLog: Identifiable {}
