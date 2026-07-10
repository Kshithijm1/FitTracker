import SwiftData
import Observation
import Foundation

/// Single composition root: owns the SwiftData stack and hands out
/// service instances so views never construct dependencies themselves.
@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let foodSearch: FoodSearchService
    let prDetector: PRDetectorService
    let appLock: AppLockController
    let auth: AuthService
    let syncEngine: SyncEngine
    let healthKit: HealthKitService
    let memory: MemoryService
    let ai: AIService

    private(set) var didSeedExercises = false

    init() {
        let schema = Schema([
            UserProfile.self, Goals.self,
            Exercise.self, Routine.self, RoutineItem.self,
            Workout.self, WorkoutItem.self, SetEntry.self, PersonalRecord.self,
            WeightEntry.self, MeasurementEntry.self, ProgressPhoto.self,
            FoodItem.self, SavedMeal.self, SavedMealItem.self, FoodLog.self,
            WaterEntry.self, SleepEntry.self, StepsCache.self,
            MemoryItem.self, ChatMessage.self,
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
        Self.applyFileProtection(to: configuration.url)

        self.foodSearch = FoodSearchService(context: modelContainer.mainContext)
        self.foodSearch.remoteProviders = [OpenFoodFactsProvider(), USDAProvider()]
        self.prDetector = PRDetectorService()
        self.appLock = AppLockController()
        self.auth = AuthService()
        self.syncEngine = SyncEngine(context: modelContainer.mainContext)
        self.healthKit = HealthKitService(context: modelContainer.mainContext)
        self.memory = MemoryService(context: modelContainer.mainContext)
        self.ai = AIService(memory: memory, modelContainer: modelContainer, auth: auth)
    }

    /// Runs once at launch: seeds the built-in exercise library on first run only.
    func bootstrap() async {
        guard !didSeedExercises else { return }
        await ExerciseSeeder.seedIfNeeded(context: modelContainer.mainContext)
        didSeedExercises = true
    }

    /// SwiftData doesn't expose a file-protection option on `ModelConfiguration`,
    /// so it's applied directly to the SQLite store files on disk (PLAN.md §5:
    /// `.completeUntilFirstUserAuthentication`). Covers the store's `-wal`/`-shm`
    /// siblings too, since SwiftData's default journal mode writes through those.
    private static func applyFileProtection(to storeURL: URL) {
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
}
