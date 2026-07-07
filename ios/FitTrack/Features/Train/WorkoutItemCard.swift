import SwiftUI
import SwiftData

extension WorkoutItem: Identifiable {}
extension SetEntry: Identifiable {}

struct WorkoutItemCard: View {
    @Bindable var item: WorkoutItem
    let exerciseName: String
    let onSetCompleted: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var previousSets: [SetEntry]

    init(item: WorkoutItem, exerciseName: String, onSetCompleted: @escaping () -> Void) {
        self.item = item
        self.exerciseName = exerciseName
        self.onSetCompleted = onSetCompleted
        let exerciseID = item.exerciseID
        let currentWorkoutItemID = item.id
        _previousSets = Query(
            filter: #Predicate<SetEntry> { set in
                set.workoutItem?.exerciseID == exerciseID
                    && set.workoutItem?.id != currentWorkoutItemID
                    && set.completedAt != nil
            },
            sort: [SortDescriptor(\.completedAt, order: .reverse)]
        )
    }

    private var previousSummary: String? {
        guard !previousSets.isEmpty else { return nil }
        let mostRecentDate = previousSets.first?.completedAt
        let sameSession = previousSets.prefix(while: { set in
            guard let mostRecentDate, let completedAt = set.completedAt else { return false }
            return Calendar.current.isDate(completedAt, inSameDayAs: mostRecentDate)
        })
        return sameSession
            .sorted(by: { $0.index < $1.index })
            .map { "\(Int($0.weightKG))×\($0.reps)" }
            .joined(separator: ", ")
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(exerciseName)
                    .font(Theme.Font.title22)
                    .foregroundStyle(Theme.Color.textPrimary)

                if let previousSummary {
                    Text("last: \(previousSummary)")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                ForEach(item.sets.sorted(by: { $0.index < $1.index })) { set in
                    SetRow(set: set) {
                        set.completedAt = .now
                        set.markDirty()
                        try? context.save()
                        onSetCompleted()
                    }
                }

                Button {
                    addSet()
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(Theme.Font.caption13)
                }
            }
        }
    }

    private func addSet() {
        let lastSet = item.sets.sorted(by: { $0.index < $1.index }).last
        let newSet = SetEntry(
            index: item.sets.count,
            weightKG: lastSet?.weightKG ?? 20,
            reps: lastSet?.reps ?? 8
        )
        item.sets.append(newSet)
        try? context.save()
    }
}

private struct SetRow: View {
    @Bindable var set: SetEntry
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(set.index + 1)")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textTertiary)
                .frame(minWidth: 16, alignment: .trailing)
                .accessibilityLabel("Set \(set.index + 1)")

            CompactStepper(value: Binding(
                get: { set.weightKG },
                set: { set.weightKG = $0; set.markDirty() }
            ), step: 2.5, label: "weight")

            Text("×")
                .foregroundStyle(Theme.Color.textTertiary)
                .accessibilityHidden(true)

            CompactStepper(value: Binding(
                get: { Double(set.reps) },
                set: { set.reps = Int($0); set.markDirty() }
            ), step: 1, label: "reps")

            Spacer()

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(set.isCompleted ? Theme.Color.accent : Theme.Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(set.isCompleted)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Mark set complete")
            .accessibilityValue(set.isCompleted ? "Completed" : "Not completed")
        }
    }
}
