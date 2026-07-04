import Foundation
import SwiftData

private struct SeedExercise: Decodable {
    let name: String
    let muscleGroups: [String]
    let equipment: String
}

/// Loads `Resources/exercises.json` into SwiftData exactly once. Safe to
/// call on every launch — it no-ops once any built-in `Exercise` exists,
/// so user edits/archives to seeded rows are never clobbered.
enum ExerciseSeeder {
    @MainActor
    static func seedIfNeeded(context: ModelContext) async {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json missing from app bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let seeds = try JSONDecoder().decode([SeedExercise].self, from: data)
            for seed in seeds {
                let exercise = Exercise(
                    name: seed.name,
                    muscleGroups: seed.muscleGroups,
                    equipment: seed.equipment,
                    isCustom: false
                )
                exercise.dirty = false // built-ins are bundled, not user-authored — nothing to push
                context.insert(exercise)
            }
            try context.save()
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }
}
