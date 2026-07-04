import SwiftData
import Observation

/// Single composition root: owns the SwiftData stack and hands out
/// service instances so views never construct dependencies themselves.
@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let foodSearch: FoodSearchService
    let prDetector: PRDetectorService
    let appLock: AppLockController

    private(set) var didSeedExercises = false

    init() {
        let schema = Schema([
            UserProfile.self, Goals.self,
            Exercise.self, Routine.self, RoutineItem.self,
            Workout.self, WorkoutItem.self, SetEntry.self, PersonalRecord.self,
            WeightEntry.self, MeasurementEntry.self, ProgressPhoto.self,
            FoodItem.self, SavedMeal.self, SavedMealItem.self, FoodLog.self,
            WaterEntry.self, SleepEntry.self, StepsCache.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        self.foodSearch = FoodSearchService(context: modelContainer.mainContext)
        self.prDetector = PRDetectorService()
        self.appLock = AppLockController()
    }

    /// Runs once at launch: seeds the built-in exercise library on first run only.
    func bootstrap() async {
        guard !didSeedExercises else { return }
        await ExerciseSeeder.seedIfNeeded(context: modelContainer.mainContext)
        didSeedExercises = true
    }
}
