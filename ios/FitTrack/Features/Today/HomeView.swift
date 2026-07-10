import SwiftUI
import SwiftData
import WidgetKit

/// The landing page. Top to bottom: greeting → ask-the-coach bar →
/// day/week/month progress → calorie ring (with training bonus) →
/// three configurable quick-log tiles → contextual meal + workout cards.
/// Everything renders from local data before any network call.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container

    @Query private var profiles: [UserProfile]
    @Query private var goalsList: [Goals]
    @Query private var todayLogs: [FoodLog]
    @Query private var todayWater: [WaterEntry]
    @Query private var todaySteps: [StepsCache]
    @Query private var todayWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.finishedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var inProgressWorkouts: [Workout]

    @State private var showingLogSheet = false
    @State private var showingWorkoutSheet = false
    @State private var showingCoach = false

    init() {
        let (start, end) = Self.todayBounds()
        _todayLogs = Query(filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end })
        _todayWater = Query(filter: #Predicate<WaterEntry> { $0.date >= start && $0.date < end })
        _todaySteps = Query(filter: #Predicate<StepsCache> { $0.date >= start && $0.date < end })
        _todayWorkouts = Query(filter: #Predicate<Workout> { $0.finishedAt != nil && $0.startedAt >= start })
    }

    private static func todayBounds() -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private var goals: Goals { goalsList.first ?? Goals() }
    private var profile: UserProfile? { profiles.first }

    private var consumed: MacroSet {
        todayLogs.filter { $0.deletedAt == nil }.reduce(MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0)) { acc, log in
            MacroSet(
                kcal: acc.kcal + log.macroSnapshot.kcal,
                protein: acc.protein + log.macroSnapshot.protein,
                carbs: acc.carbs + log.macroSnapshot.carbs,
                fat: acc.fat + log.macroSnapshot.fat
            )
        }
    }

    private var burnedToday: Int {
        todayWorkouts.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.caloriesBurned }
    }

    private var waterML: Int { todayWater.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.amountML } }
    private var stepsCount: Int { todaySteps.first?.steps ?? 0 }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profile?.displayName.split(separator: " ").first.map(String.init) ?? ""
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<18: base = "Good afternoon"
        default: base = "Good evening"
        }
        return name.isEmpty || name == "You" ? base : "\(base), \(name)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    header

                    coachBar

                    PeriodProgressCard()

                    CalorieRingSection(goals: goals, consumed: consumed, burnedKcal: burnedToday)

                    QuickLogTiles()

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
            .fullScreenCover(isPresented: $showingCoach) {
                CoachChatView()
            }
            .onAppear { updateWidgetSnapshot() }
            .onChange(of: consumed.kcal) { _, _ in updateWidgetSnapshot() }
            .onChange(of: waterML) { _, _ in updateWidgetSnapshot() }
            .onChange(of: stepsCount) { _, _ in updateWidgetSnapshot() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Theme.Font.display28)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.xs)
    }

    /// One-tap entry into a fully personalized AI conversation.
    private var coachBar: some View {
        Button {
            showingCoach = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.Color.accent)
                Text("Ask your coach anything…")
                    .font(Theme.Font.body17)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Color.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask your coach anything")
    }

    /// Keeps the Home rings widget in sync — written to the shared App
    /// Group container every time ring-relevant data changes.
    private func updateWidgetSnapshot() {
        let snapshot = TodaySnapshot(
            kcalRemaining: MacroMath.remaining(target: goals.calorieTarget + burnedToday, consumed: Int(consumed.kcal)),
            kcalTarget: goals.calorieTarget,
            waterGlasses: waterML / 250,
            waterGoalGlasses: max(goals.waterML / 250, 1),
            steps: stepsCount,
            stepGoal: goals.stepTarget,
            updatedAt: .now
        )
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayRingsWidget")
    }
}

#Preview {
    HomeView()
        .environment(AppContainer())
        .modelContainer(for: [Goals.self, FoodLog.self, WaterEntry.self], inMemory: true)
}
