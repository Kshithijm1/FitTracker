import SwiftUI
import SwiftData

struct TrainHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.position) private var routines: [Routine]
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]

    @State private var startedWorkout: Workout?
    @State private var showingNewRoutine = false

    private var lastFinishedWorkout: Workout? {
        allWorkouts.first { $0.finishedAt != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if let last = lastFinishedWorkout {
                    Section {
                        Button {
                            startedWorkout = WorkoutStarter.repeatWorkout(last, context: context)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text("Repeat last workout")
                                        .font(Theme.Font.bodyEmphasized17)
                                    Text(last.startedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Theme.Color.accent)
                            }
                        }
                    }
                }

                Section("Routines") {
                    if routines.isEmpty {
                        ContentUnavailableView(
                            "No routines yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Create a routine to speed up logging, or start an empty workout below.")
                        )
                    } else {
                        ForEach(routines) { routine in
                            Button {
                                startedWorkout = WorkoutStarter.start(from: routine, context: context)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(routine.name)
                                        .font(Theme.Font.bodyEmphasized17)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text("\(routine.items.count) exercises")
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Start empty workout") {
                        startedWorkout = WorkoutStarter.start(from: nil, context: context)
                    }
                    Button("New routine") {
                        showingNewRoutine = true
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Train")
            .sheet(item: $startedWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
            .sheet(isPresented: $showingNewRoutine) {
                RoutineEditorView()
            }
        }
    }

}

extension Workout: Identifiable {}
extension Routine: Identifiable {}

#Preview {
    TrainHomeView()
        .modelContainer(for: [Routine.self, Workout.self], inMemory: true)
}
