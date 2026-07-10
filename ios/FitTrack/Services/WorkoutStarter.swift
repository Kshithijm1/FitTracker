import Foundation
import SwiftData

/// Shared "create a `Workout` and its `WorkoutItem`s" logic used by both
/// the Home quick-start card and the Train tab, so routine/repeat-last
/// semantics stay in one place.
///
/// Starting from a routine (or repeating a workout) pre-fills every
/// exercise's sets from the user's most recent session of that exercise —
/// in the gym you only confirm/adjust, never re-type (PLAN.md §3's
/// "1 tap per set" promise).
enum WorkoutStarter {
    /// Fetches only the single most recent finished workout — not the
    /// user's entire history — for "Repeat last workout" cards.
    static var lastFinishedWorkoutDescriptor: FetchDescriptor<Workout> {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    @discardableResult
    static func start(from routine: Routine?, context: ModelContext) -> Workout {
        let workout = Workout(routineID: routine?.id, name: routine?.name ?? "")
        for item in (routine?.items.sorted { $0.position < $1.position } ?? []) {
            let workoutItem = WorkoutItem(exerciseID: item.exerciseID, position: item.position)
            workoutItem.sets = prefilledSets(
                exerciseID: item.exerciseID,
                fallbackCount: item.targetSets,
                fallbackReps: item.targetReps,
                context: context
            )
            workout.items.append(workoutItem)
        }
        context.insert(workout)
        try? context.save()
        return workout
    }

    @discardableResult
    static func repeatWorkout(_ previous: Workout, context: ModelContext) -> Workout {
        let workout = Workout(routineID: previous.routineID, name: previous.name)
        for item in previous.items.sorted(by: { $0.position < $1.position }) {
            let workoutItem = WorkoutItem(exerciseID: item.exerciseID, position: item.position)
            // Mirror the previous session's sets exactly (type + values),
            // reset to un-completed.
            let previousSets = item.sets.sorted { $0.index < $1.index }
            workoutItem.sets = previousSets.enumerated().map { index, old in
                let fresh = SetEntry(index: index, weightKG: old.weightKG, reps: old.reps, setType: old.setType)
                fresh.durationSec = old.durationSec
                fresh.distanceM = old.distanceM
                fresh.speedKPH = old.speedKPH
                fresh.inclinePct = old.inclinePct
                return fresh
            }
            if workoutItem.sets.isEmpty {
                workoutItem.sets = prefilledSets(exerciseID: item.exerciseID, fallbackCount: 3, fallbackReps: 8, context: context)
            }
            workout.items.append(workoutItem)
        }
        context.insert(workout)
        try? context.save()
        return workout
    }

    /// Adds an exercise to an in-progress workout with history-prefilled sets.
    @discardableResult
    static func addExercise(_ exercise: Exercise, to workout: Workout, context: ModelContext) -> WorkoutItem {
        let item = WorkoutItem(exerciseID: exercise.id, position: (workout.items.map(\.position).max() ?? -1) + 1)
        item.sets = prefilledSets(exerciseID: exercise.id, fallbackCount: 3, fallbackReps: 8, context: context)
        workout.items.append(item)
        try? context.save()
        return item
    }

    /// The user's most recent same-day block of completed sets for this
    /// exercise, cloned as fresh un-completed rows; falls back to sensible
    /// defaults for a first-ever session.
    static func prefilledSets(
        exerciseID: UUID,
        fallbackCount: Int,
        fallbackReps: Int,
        context: ModelContext
    ) -> [SetEntry] {
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> {
                $0.workoutItem?.exerciseID == exerciseID && $0.completedAt != nil
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        let history = (try? context.fetch(descriptor)) ?? []

        if let mostRecent = history.first?.completedAt {
            let lastSession = history
                .prefix { set in
                    guard let completedAt = set.completedAt else { return false }
                    return Calendar.current.isDate(completedAt, inSameDayAs: mostRecent)
                }
                .sorted { $0.index < $1.index }
            if !lastSession.isEmpty {
                return lastSession.enumerated().map { index, old in
                    let fresh = SetEntry(index: index, weightKG: old.weightKG, reps: old.reps, setType: old.setType)
                    fresh.durationSec = old.durationSec
                    fresh.distanceM = old.distanceM
                    fresh.speedKPH = old.speedKPH
                    fresh.inclinePct = old.inclinePct
                    return fresh
                }
            }
        }

        return (0..<max(fallbackCount, 1)).map { index in
            SetEntry(index: index, weightKG: 20, reps: fallbackReps)
        }
    }
}
