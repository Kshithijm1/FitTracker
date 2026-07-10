import SwiftUI
import SwiftData

/// Every past workout, newest first. Tap for the full breakdown; any
/// workout can become a reusable routine or be repeated as today's session.
struct WorkoutHistoryView: View {
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt != nil },
        sort: \Workout.startedAt,
        order: .reverse
    ) private var workouts: [Workout]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Finished workouts appear here with full stats.")
                )
            } else {
                List {
                    ForEach(workouts.filter { $0.deletedAt == nil }) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            HistoryRow(workout: workout)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .background(Theme.Color.background)
    }
}

private struct HistoryRow: View {
    let workout: Workout

    private var completedSets: Int {
        workout.items.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var durationMinutes: Int {
        guard let finishedAt = workout.finishedAt else { return 0 }
        return Int(finishedAt.timeIntervalSince(workout.startedAt) / 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(workout.name.isEmpty ? "Workout" : workout.name)
                .font(Theme.Font.bodyEmphasized17)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(
                "\(workout.startedAt.formatted(date: .abbreviated, time: .omitted)) · "
                + "\(completedSets) sets · \(durationMinutes) min"
                + (workout.caloriesBurned > 0 ? " · \(workout.caloriesBurned) kcal" : "")
            )
            .font(Theme.Font.caption13)
            .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

// MARK: - Detail

struct WorkoutDetailView: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \Routine.position) private var routines: [Routine]

    @State private var savedAsRoutine = false
    @State private var startedWorkout: Workout?

    private var exercisesByID: [UUID: Exercise] {
        Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var completedSets: [SetEntry] {
        workout.items.flatMap(\.sets).filter(\.isCompleted)
    }

    private var totalVolume: Double {
        completedSets.reduce(0) { $0 + StrengthMath.volume(weightKG: $1.weightKG, reps: $1.reps) }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.lg) {
                    stat("\(completedSets.count)", "sets")
                    stat(totalVolume.formatted(.number.precision(.fractionLength(0))), "kg volume")
                    stat("\(workout.caloriesBurned)", "kcal")
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Theme.Color.surface)
            }

            ForEach(workout.items.sorted(by: { $0.position < $1.position })) { item in
                Section(exercisesByID[item.exerciseID]?.name ?? "Exercise") {
                    ForEach(item.sets.sorted(by: { $0.index < $1.index })) { set in
                        HStack {
                            Text(set.setType.badge ?? "\(set.index + 1)")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .frame(width: 24)
                            Text(setDescription(set, kind: exercisesByID[item.exerciseID]?.trackingKind ?? .weightReps))
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            if set.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.Color.accent)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    startedWorkout = WorkoutStarter.repeatWorkout(workout, context: context)
                } label: {
                    Label("Repeat this workout", systemImage: "arrow.clockwise")
                }
                Button {
                    saveAsRoutine()
                } label: {
                    Label(savedAsRoutine ? "Saved to routines ✓" : "Save as routine", systemImage: "square.and.arrow.down")
                }
                .disabled(savedAsRoutine)
            }
        }
        .navigationTitle(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
        .fullScreenCover(item: $startedWorkout) { started in
            WorkoutSessionView(workout: started)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.numeral(20))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func setDescription(_ set: SetEntry, kind: ExerciseTrackingKind) -> String {
        switch kind {
        case .weightReps, .bodyweightReps:
            return "\(String(format: "%g", set.weightKG)) kg × \(set.reps)"
        case .timeOnly:
            return "\(set.durationSec / 60) min"
        case .cardioSpeedIncline:
            return String(format: "%d min @ %.1f km/h · %.1f%%", set.durationSec / 60, set.speedKPH, set.inclinePct)
        case .cardioDistance:
            return String(format: "%d min · %.2f km", set.durationSec / 60, set.distanceM / 1000)
        }
    }

    private func saveAsRoutine() {
        let routine = Routine(
            name: workout.name.isEmpty
                ? "Workout \(workout.startedAt.formatted(date: .abbreviated, time: .omitted))"
                : workout.name,
            position: routines.count
        )
        for item in workout.items.sorted(by: { $0.position < $1.position }) {
            let workingSets = item.sets.filter { $0.setType != .warmup }
            routine.items.append(RoutineItem(
                exerciseID: item.exerciseID,
                position: item.position,
                targetSets: max(workingSets.count, 1),
                targetReps: workingSets.first?.reps ?? 8
            ))
        }
        context.insert(routine)
        try? context.save()
        savedAsRoutine = true
        Haptics.success()
    }
}
