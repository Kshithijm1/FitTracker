import Foundation
import SwiftData

/// Shared "create a `Workout` and its `WorkoutItem`s" logic used by both
/// the Today quick-start card and the Train tab, so routine/repeat-last
/// semantics stay in one place.
enum WorkoutStarter {
    @discardableResult
    static func start(from routine: Routine?, context: ModelContext) -> Workout {
        let workout = Workout(routineID: routine?.id)
        for item in (routine?.items.sorted { $0.position < $1.position } ?? []) {
            workout.items.append(WorkoutItem(exerciseID: item.exerciseID, position: item.position))
        }
        context.insert(workout)
        try? context.save()
        return workout
    }

    @discardableResult
    static func repeatWorkout(_ previous: Workout, context: ModelContext) -> Workout {
        let workout = Workout(routineID: previous.routineID)
        for item in previous.items.sorted(by: { $0.position < $1.position }) {
            workout.items.append(WorkoutItem(exerciseID: item.exerciseID, position: item.position))
        }
        context.insert(workout)
        try? context.save()
        return workout
    }
}
