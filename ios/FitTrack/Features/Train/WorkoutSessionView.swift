import SwiftUI
import SwiftData

/// The live workout screen. One card per exercise, one row per set,
/// checkmark = logged + rest timer (user-configurable length). Exercises
/// reorder via each card's menu; adding an exercise offers both search
/// and "snap a photo of the equipment" (AI suggestions).
struct WorkoutSessionView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var profiles: [UserProfile]

    @AppStorage("restTimerSeconds") private var restTimerSeconds = 90

    @State private var restTimer = RestTimerService()
    @State private var showingExercisePicker = false
    @State private var showingEquipmentPhoto = false
    @State private var showingSummary = false
    @State private var showingDiscardConfirm = false
    @State private var recentPR: (exerciseName: String, kind: PersonalRecordKind)?

    private var profile: UserProfile? { profiles.first }
    private var exercisesByID: [UUID: Exercise] {
        Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var sortedItems: [WorkoutItem] {
        workout.items.sorted { $0.position < $1.position }
    }
    private var completedSetCount: Int {
        workout.items.flatMap(\.sets).filter(\.isCompleted).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    sessionHeader

                    if restTimer.isRunning {
                        RestTimerBanner(seconds: restTimer.remainingSeconds) {
                            restTimer.cancel()
                        }
                    }

                    ForEach(sortedItems) { item in
                        WorkoutItemCard(
                            item: item,
                            exercise: exercisesByID[item.exerciseID],
                            weightUnit: profile?.unitPreference ?? .imperial,
                            distanceUnit: profile?.distanceUnit ?? .kilometers,
                            onSetCompleted: { handleSetCompleted(item: item) },
                            onMove: { direction in move(item, direction: direction) },
                            onRemove: { remove(item) }
                        )
                    }

                    addExerciseButtons
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle(workout.name.isEmpty ? "Workout" : workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("Keep going", systemImage: "play.fill") {}
                        Button("Discard workout", systemImage: "trash", role: .destructive) {
                            showingDiscardConfirm = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close options")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finishWorkout() }
                        .fontWeight(.semibold)
                        .disabled(completedSetCount == 0)
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
                    WorkoutStarter.addExercise(exercise, to: workout, context: context)
                }
            }
            .sheet(isPresented: $showingEquipmentPhoto) {
                EquipmentPhotoView { exercise, detectedWeightKG in
                    let item = WorkoutStarter.addExercise(exercise, to: workout, context: context)
                    if let weight = detectedWeightKG, weight > 0 {
                        // Pre-fill the first set with the weight read from
                        // the photo; later sets clone it via "Add set".
                        for set in item.sets.sorted(by: { $0.index < $1.index }) {
                            set.weightKG = weight
                            set.markDirty()
                        }
                        try? context.save()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingSummary) {
                WorkoutSummaryView(workout: workout) {
                    dismiss()
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingDiscardConfirm) {
                Button("Discard workout", role: .destructive) {
                    context.delete(workout)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("All sets from this session will be deleted.")
            }
        }
    }

    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.startedAt, style: .timer)
                    .font(Theme.Font.numeral(22))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(completedSetCount) sets done")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Color.accent)
        }
        .padding(.horizontal, Theme.Spacing.xxs)
    }

    private var addExerciseButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                showingExercisePicker = true
            } label: {
                Label("Add exercise", systemImage: "plus.circle.fill")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .buttonStyle(.plain)

            Button {
                showingEquipmentPhoto = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photograph equipment for AI suggestions")
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Actions

    private func handleSetCompleted(item: WorkoutItem) {
        guard let lastSet = item.sets.sorted(by: { $0.index < $1.index }).last(where: \.isCompleted) else { return }

        let priorRecords = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        let achieved = container.prDetector.evaluate(
            set: lastSet,
            exerciseID: item.exerciseID,
            priorRecords: priorRecords,
            context: context
        )

        restTimer.start(
            seconds: TimeInterval(max(restTimerSeconds, 10)),
            exerciseName: exercisesByID[item.exerciseID]?.name ?? "Rest"
        )
        Haptics.light()

        if let kind = achieved.first {
            Haptics.success()
            let name = exercisesByID[item.exerciseID]?.name ?? "Exercise"
            withAnimation(Theme.Motion.spring(reduceMotion: reduceMotion)) {
                recentPR = (name, kind)
            }
            container.memory.remember(
                "New \(kind.rawValue) PR on \(name): \(String(format: "%.1f", prValue(kind: kind, set: lastSet))).",
                kind: "workout"
            )
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(Theme.Motion.spring(reduceMotion: reduceMotion)) { recentPR = nil }
            }
        }
    }

    private func prValue(kind: PersonalRecordKind, set: SetEntry) -> Double {
        switch kind {
        case .weight: return set.weightKG
        case .reps: return Double(set.reps)
        case .volume: return StrengthMath.volume(weightKG: set.weightKG, reps: set.reps)
        case .e1RM: return StrengthMath.estimatedOneRepMax(weightKG: set.weightKG, reps: set.reps)
        }
    }

    private func move(_ item: WorkoutItem, direction: Int) {
        var items = sortedItems
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let target = index + direction
        guard items.indices.contains(target) else { return }
        items.swapAt(index, target)
        for (position, moved) in items.enumerated() {
            moved.position = position
            moved.markDirty()
        }
        try? context.save()
        Haptics.light()
    }

    private func remove(_ item: WorkoutItem) {
        context.delete(item)
        for (position, remaining) in sortedItems.filter({ $0.id != item.id }).enumerated() {
            remaining.position = position
        }
        try? context.save()
    }

    private func finishWorkout() {
        restTimer.cancel()
        workout.finishedAt = .now

        // Deterministic MET-based estimate; the AI only narrates on top.
        let bodyweight = latestBodyweightKG()
        let duration = Int((workout.finishedAt ?? .now).timeIntervalSince(workout.startedAt))
        let cardioSets: [(Int, Double, Double)] = workout.items.flatMap { item in
            let kind = exercisesByID[item.exerciseID]?.trackingKind ?? .weightReps
            guard kind == .cardioSpeedIncline || kind == .cardioDistance || kind == .timeOnly else {
                return [(Int, Double, Double)]()
            }
            return item.sets.filter(\.isCompleted).map { ($0.durationSec, $0.speedKPH, $0.inclinePct) }
        }
        workout.caloriesBurned = CalorieBurnMath.workoutKcal(
            totalDurationSec: duration,
            cardioSets: cardioSets,
            bodyweightKG: bodyweight
        )
        workout.markDirty()
        try? context.save()

        let name = workout.name.isEmpty ? "Workout" : workout.name
        container.memory.remember(
            "Finished \(name): \(completedSetCount) sets in \(duration / 60) minutes, ~\(workout.caloriesBurned) kcal.",
            kind: "workout"
        )
        showingSummary = true
    }

    private func latestBodyweightKG() -> Double {
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.weightKG ?? 0
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
                    .contentTransition(.numericText())
                Spacer()
                Button("Skip", action: onSkip)
                    .font(Theme.Font.caption13)
            }
        }
    }
}
