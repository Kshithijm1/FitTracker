import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var restTimer = RestTimerService()
    @State private var showingExercisePicker = false
    @State private var showingSummary = false
    @State private var recentPR: (exerciseName: String, kind: PersonalRecordKind)?

    private func exerciseName(for id: UUID) -> String {
        allExercises.first { $0.id == id }?.name ?? "Exercise"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if restTimer.isRunning {
                        RestTimerBanner(seconds: restTimer.remainingSeconds) {
                            restTimer.cancel()
                        }
                    }

                    ForEach(workout.items.sorted(by: { $0.position < $1.position })) { item in
                        WorkoutItemCard(
                            item: item,
                            exerciseName: exerciseName(for: item.exerciseID),
                            onSetCompleted: { handleSetCompleted(item: item) }
                        )
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle(workout.startedAt.formatted(date: .omitted, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        finishWorkout()
                    }
                    .disabled(workout.items.isEmpty)
                }
            }
            .overlay(alignment: .top) {
                if let recentPR {
                    PRBadge(kind: "\(recentPR.exerciseName) \(recentPR.kind.rawValue)")
                        .padding(.top, Theme.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let position = workout.items.count
                    workout.items.append(WorkoutItem(exerciseID: exercise.id, position: position))
                    try? context.save()
                }
            }
            .fullScreenCover(isPresented: $showingSummary) {
                WorkoutSummaryView(workout: workout) {
                    dismiss()
                }
            }
        }
    }

    private func handleSetCompleted(item: WorkoutItem) {
        guard let lastSet = item.sets.sorted(by: { $0.index < $1.index }).last(where: \.isCompleted) else { return }

        let achieved = (try? container.prDetector.evaluate(
            set: lastSet,
            exerciseID: item.exerciseID,
            context: context
        )) ?? []

        restTimer.start(seconds: 90, exerciseName: exerciseName(for: item.exerciseID))
        Haptics.light()

        if let kind = achieved.first {
            Haptics.success()
            withAnimation(Theme.Motion.spring(reduceMotion: reduceMotion)) {
                recentPR = (exerciseName(for: item.exerciseID), kind)
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(Theme.Motion.spring(reduceMotion: reduceMotion)) { recentPR = nil }
            }
        }
    }

    private func finishWorkout() {
        workout.finishedAt = .now
        workout.markDirty()
        try? context.save()
        showingSummary = true
    }
}

private struct RestTimerBanner: View {
    let seconds: Int
    let onSkip: () -> Void

    var body: some View {
        Card {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.Color.accent)
                Text("Rest · \(seconds)s")
                    .font(Theme.Font.numeral(17))
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Button("Skip", action: onSkip)
                    .font(Theme.Font.caption13)
            }
        }
    }
}
