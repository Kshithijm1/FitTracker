import Foundation
import SwiftData

private struct SeedExercise: Decodable {
    let name: String
    let muscleGroups: [String]
    let equipment: String
    let kind: String?
}

/// Loads `Resources/exercises.json` into SwiftData exactly once. Safe to
/// call on every launch — it no-ops once any built-in `Exercise` exists,
/// so user edits/archives to seeded rows are never clobbered. It does,
/// however, top up: seed entries whose *name* isn't present yet are added,
/// and built-ins still on the default tracking kind adopt the seed's kind —
/// so stores created before cardio/time tracking existed pick it up.
enum ExerciseSeeder {
    @MainActor
    static func seedIfNeeded(context: ModelContext) async {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json missing from app bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let seeds = try JSONDecoder().decode([SeedExercise].self, from: data)

            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })
            let existing = (try? context.fetch(descriptor)) ?? []
            let existingByName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

            var changed = false
            for seed in seeds {
                let kind = ExerciseTrackingKind(rawValue: seed.kind ?? "") ?? .weightReps
                if let current = existingByName[seed.name] {
                    // Backfill tracking kinds introduced after first seed.
                    if current.trackingKind == .weightReps && kind != .weightReps {
                        current.trackingKind = kind
                        changed = true
                    }
                    continue
                }
                let exercise = Exercise(
                    name: seed.name,
                    muscleGroups: seed.muscleGroups,
                    equipment: seed.equipment,
                    isCustom: false,
                    trackingKind: kind
                )
                exercise.dirty = false // built-ins are bundled, not user-authored — nothing to push
                context.insert(exercise)
                changed = true
            }
            if changed {
                try context.save()
            }
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }
}
