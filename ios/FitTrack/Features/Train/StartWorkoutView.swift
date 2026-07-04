import SwiftUI
import SwiftData

/// Presented from Today's "Start workout" card when nothing is in
/// progress. Offers the last routine front-and-center, falling back to a
/// full routine list or an empty workout.
struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.position) private var routines: [Routine]
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]

    @State private var startedWorkout: Workout?

    private var lastFinishedWorkout: Workout? {
        allWorkouts.first { $0.finishedAt != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if let last = lastFinishedWorkout {
                    Button("Repeat: \(routineName(for: last))") {
                        startedWorkout = WorkoutStarter.repeatWorkout(last, context: context)
                    }
                }
                ForEach(routines) { routine in
                    Button(routine.name) {
                        startedWorkout = WorkoutStarter.start(from: routine, context: context)
                    }
                }
                Button("Start empty workout") {
                    startedWorkout = WorkoutStarter.start(from: nil, context: context)
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(item: $startedWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
        }
    }

    private func routineName(for workout: Workout) -> String {
        routines.first { $0.id == workout.routineID }?.name ?? "last workout"
    }
}

#Preview {
    StartWorkoutView()
        .modelContainer(for: [Routine.self, Workout.self], inMemory: true)
}
