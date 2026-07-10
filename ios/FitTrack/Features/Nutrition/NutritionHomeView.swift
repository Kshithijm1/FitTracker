import SwiftUI
import SwiftData

/// Nutrition tab home. Top: calories left today (training bonus called out
/// in its own color) — tap for the day/week detail. Below: macro bars,
/// then Breakfast / Lunch / Dinner / Snacks sections that each log into
/// the right slot. My Foods and Recipes live in the toolbar.
struct NutritionHomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var todayLogs: [FoodLog]
    @Query private var todayWorkouts: [Workout]
    @Query private var goalsList: [Goals]

    @State private var loggingSlot: MealSlot?
    @State private var foodNamesByID: [UUID: String] = [:]
    @State private var showingMyFoods = false
    @State private var showingRecipes = false

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _todayLogs = Query(
            filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\.date)]
        )
        _todayWorkouts = Query(filter: #Predicate<Workout> { $0.finishedAt != nil && $0.startedAt >= start })
    }

    private var goals: Goals { goalsList.first ?? Goals() }
    private var visibleLogs: [FoodLog] { todayLogs.filter { $0.deletedAt == nil } }
    private var burnedToday: Int { todayWorkouts.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.caloriesBurned } }

    private var consumed: MacroSet {
        visibleLogs.reduce(MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0)) { acc, log in
            MacroSet(
                kcal: acc.kcal + log.macroSnapshot.kcal,
                protein: acc.protein + log.macroSnapshot.protein,
                carbs: acc.carbs + log.macroSnapshot.carbs,
                fat: acc.fat + log.macroSnapshot.fat
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    NavigationLink {
                        CalorieDetailView()
                    } label: {
                        CalorieHeaderCard(goals: goals, consumed: consumed, burnedKcal: burnedToday)
                    }
                    .buttonStyle(.plain)

                    macroBars

                    ForEach(MealSlot.allCases, id: \.self) { slot in
                        MealSection(
                            slot: slot,
                            logs: visibleLogs.filter { $0.slot == slot },
                            foodName: { foodNamesByID[$0] ?? "Food" },
                            onAdd: { loggingSlot = slot },
                            onDelete: { delete($0) }
                        )
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingMyFoods = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("My foods")
                    Button {
                        showingRecipes = true
                    } label: {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel("Recipes and meals")
                }
            }
            .sheet(item: $loggingSlot) { slot in
                LogMealSheet(slot: slot)
            }
            .sheet(isPresented: $showingMyFoods) {
                MyFoodsView()
            }
            .sheet(isPresented: $showingRecipes) {
                RecipeListView()
            }
            .onAppear { refreshFoodNames() }
            .onChange(of: todayLogs.count) { _, _ in refreshFoodNames() }
        }
    }

    private var macroBars: some View {
        Card {
            VStack(spacing: Theme.Spacing.sm) {
                StatBar(
                    label: "Protein",
                    valueText: "\(Int(consumed.protein)) / \(goals.proteinG)g",
                    progress: consumed.protein / Double(max(goals.proteinG, 1))
                )
                StatBar(
                    label: "Carbs",
                    valueText: "\(Int(consumed.carbs)) / \(goals.carbsG)g",
                    progress: consumed.carbs / Double(max(goals.carbsG, 1))
                )
                StatBar(
                    label: "Fat",
                    valueText: "\(Int(consumed.fat)) / \(goals.fatG)g",
                    progress: consumed.fat / Double(max(goals.fatG, 1))
                )
            }
        }
    }

    /// Looks up only the handful of `FoodItem`s referenced by today's logs.
    private func refreshFoodNames() {
        let ids = Set(todayLogs.map(\.foodItemID))
        guard !ids.isEmpty else {
            foodNamesByID = [:]
            return
        }
        let items = (try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        foodNamesByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
    }

    private func delete(_ log: FoodLog) {
        log.markDeleted()
        try? context.save()
    }
}

extension FoodLog: Identifiable {}
extension MealSlot: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Calorie header

private struct CalorieHeaderCard: View {
    let goals: Goals
    let consumed: MacroSet
    let burnedKcal: Int

    private var budget: Int { goals.calorieTarget + burnedKcal }
    private var remaining: Int { MacroMath.remaining(target: budget, consumed: Int(consumed.kcal)) }

    var body: some View {
        Card {
            HStack(spacing: Theme.Spacing.md) {
                ProgressRing(
                    progress: MacroMath.fractionConsumed(target: budget, consumed: Int(consumed.kcal)),
                    lineWidth: 8
                )
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Theme.Color.textPrimary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("\(remaining) kcal left")
                        .font(Theme.Font.display28)
                        .foregroundStyle(Theme.Color.textPrimary)
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text("\(Int(consumed.kcal)) of \(goals.calorieTarget)")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                        if burnedKcal > 0 {
                            Text("+\(burnedKcal) 🔥")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.warning)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .accessibilityLabel("\(remaining) calories left today. Tap for details.")
    }
}

// MARK: - Meal section

private struct MealSection: View {
    let slot: MealSlot
    let logs: [FoodLog]
    let foodName: (UUID) -> String
    let onAdd: () -> Void
    let onDelete: (FoodLog) -> Void

    private var slotKcal: Int {
        Int(logs.reduce(0) { $0 + $1.macroSnapshot.kcal })
    }

    private var icon: String {
        switch slot {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label(slot == .snack ? "Snacks" : slot.rawValue.capitalized, systemImage: icon)
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    if slotKcal > 0 {
                        Text("\(slotKcal) kcal")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Color.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(slot.rawValue)")
                }

                ForEach(logs) { log in
                    HStack {
                        Text(foodName(log.foodItemID))
                            .font(Theme.Font.body17)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(log.macroSnapshot.kcal)) kcal")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                        Menu {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                onDelete(log)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Color.textTertiary)
                                .frame(width: 28, height: 28)
                        }
                        .accessibilityLabel("Options for \(foodName(log.foodItemID))")
                    }
                }
            }
        }
    }
}
