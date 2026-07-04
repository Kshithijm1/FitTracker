import SwiftUI
import SwiftData

struct NutritionHomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var allFoodItems: [FoodItem]
    @Query private var todayLogs: [FoodLog]
    @State private var showingLogSheet = false

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _todayLogs = Query(
            filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\.date)]
        )
    }

    private func foodName(for id: UUID) -> String {
        allFoodItems.first { $0.id == id }?.name ?? "Food"
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
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogMealSheet()
            }
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
