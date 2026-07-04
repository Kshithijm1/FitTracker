import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var goalsList: [Goals]
    @Query private var todayLogs: [FoodLog]
    @Query private var todayWater: [WaterEntry]
    @Query private var todaySleep: [SleepEntry]
    @Query private var todaySteps: [StepsCache]
    @Query(filter: #Predicate<Workout> { $0.finishedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var inProgressWorkouts: [Workout]

    @State private var showingLogSheet = false
    @State private var showingWorkoutSheet = false

    init() {
        let (start, end) = Self.todayBounds()
        _todayLogs = Query(filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end })
        _todayWater = Query(filter: #Predicate<WaterEntry> { $0.date >= start && $0.date < end })
        _todaySleep = Query(filter: #Predicate<SleepEntry> { $0.date >= start && $0.date < end })
        _todaySteps = Query(filter: #Predicate<StepsCache> { $0.date >= start && $0.date < end })
    }

    private static func todayBounds() -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private var goals: Goals {
        goalsList.first ?? Goals()
    }

    private var consumed: MacroSet {
        todayLogs.reduce(MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0)) { acc, log in
            MacroSet(
                kcal: acc.kcal + log.macroSnapshot.kcal,
                protein: acc.protein + log.macroSnapshot.protein,
                carbs: acc.carbs + log.macroSnapshot.carbs,
                fat: acc.fat + log.macroSnapshot.fat
            )
        }
    }

    private var waterML: Int { todayWater.reduce(0) { $0 + $1.amountML } }
    private var stepsCount: Int { todaySteps.first?.steps ?? 0 }
    private var sleepMinutes: Int { todaySleep.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    CalorieRingSection(goals: goals, consumed: consumed)

                    HabitRingsRow(
                        waterML: waterML,
                        waterGoalML: goals.waterML,
                        stepsCount: stepsCount,
                        stepGoal: goals.stepTarget,
                        sleepMinutes: sleepMinutes,
                        onAddWater: logGlassOfWater
                    )

                    QuickAddMealCard(slot: .current()) {
                        showingLogSheet = true
                    }

                    ContinueWorkoutCard(inProgressWorkout: inProgressWorkouts.first) {
                        showingWorkoutSheet = true
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLogSheet) {
                LogMealSheet()
            }
            .sheet(isPresented: $showingWorkoutSheet) {
                if let workout = inProgressWorkouts.first {
                    WorkoutSessionView(workout: workout)
                } else {
                    StartWorkoutView()
                }
            }
        }
    }

    private func logGlassOfWater() {
        withAnimation(Theme.Motion.quickSpring(reduceMotion: reduceMotion)) {
            context.insert(WaterEntry(amountML: 250))
        }
        Haptics.light()
    }
}

#Preview {
    TodayView()
        .environment(AppContainer())
        .modelContainer(for: [Goals.self, FoodLog.self, WaterEntry.self], inMemory: true)
}
