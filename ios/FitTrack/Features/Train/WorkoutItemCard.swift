import SwiftUI
import SwiftData

extension WorkoutItem: Identifiable {}
extension SetEntry: Identifiable {}

/// One exercise inside a live workout: previous-session line, one row per
/// set with inputs matched to the exercise's tracking kind, a set-type
/// badge that doubles as the type menu, and an add-set button that clones
/// the last row.
struct WorkoutItemCard: View {
    @Bindable var item: WorkoutItem
    let exercise: Exercise?
    let weightUnit: UnitPreference
    let distanceUnit: DistanceUnit
    let onSetCompleted: () -> Void
    /// Move up / move down / remove — surfaced through the header menu.
    let onMove: (Int) -> Void
    let onRemove: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var previousSets: [SetEntry]

    init(
        item: WorkoutItem,
        exercise: Exercise?,
        weightUnit: UnitPreference,
        distanceUnit: DistanceUnit,
        onSetCompleted: @escaping () -> Void,
        onMove: @escaping (Int) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.exercise = exercise
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.onSetCompleted = onSetCompleted
        self.onMove = onMove
        self.onRemove = onRemove
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

    private var trackingKind: ExerciseTrackingKind { exercise?.trackingKind ?? .weightReps }
    private var sortedSets: [SetEntry] { item.sets.sorted { $0.index < $1.index } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                header

                if let previousSummary {
                    Text("Last time: \(previousSummary)")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                ForEach(sortedSets) { set in
                    SetRow(
                        set: set,
                        kind: trackingKind,
                        normalNumber: normalSetNumber(for: set),
                        weightUnit: weightUnit,
                        distanceUnit: distanceUnit,
                        onComplete: { complete(set) },
                        onDelete: { delete(set) }
                    )
                }

                Button {
                    addSet()
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.xxs)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.name ?? "Exercise")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.textPrimary)
                if let exercise {
                    Text(exercise.muscleGroups.prefix(2).map(\.capitalized).joined(separator: " · "))
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            Spacer()
            Menu {
                Button("Move up", systemImage: "arrow.up") { onMove(-1) }
                Button("Move down", systemImage: "arrow.down") { onMove(1) }
                Divider()
                Button("Remove exercise", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(width: 44, height: 32)
            }
            .accessibilityLabel("Exercise options")
        }
    }

    /// "135×8, 135×8" for lifts; "30min @ 10km/h" style for cardio.
    private var previousSummary: String? {
        guard !previousSets.isEmpty, let mostRecentDate = previousSets.first?.completedAt else { return nil }
        let sameSession = previousSets
            .prefix(while: { set in
                guard let completedAt = set.completedAt else { return false }
                return Calendar.current.isDate(completedAt, inSameDayAs: mostRecentDate)
            })
            .sorted { $0.index < $1.index }

        switch trackingKind {
        case .weightReps, .bodyweightReps:
            return sameSession
                .map { "\(Int(Units.displayWeight($0.weightKG, unit: weightUnit)))×\($0.reps)" }
                .joined(separator: ", ")
        case .timeOnly:
            return sameSession.map { "\($0.durationSec / 60)min" }.joined(separator: ", ")
        case .cardioSpeedIncline:
            return sameSession
                .map { String(format: "%dmin @ %.1f %@", $0.durationSec / 60, Units.displaySpeed($0.speedKPH, unit: distanceUnit), Units.speedLabel(distanceUnit)) }
                .joined(separator: ", ")
        case .cardioDistance:
            return sameSession
                .map { String(format: "%dmin · %.1f %@", $0.durationSec / 60, Units.displayDistance($0.distanceM, unit: distanceUnit), Units.distanceLabel(distanceUnit)) }
                .joined(separator: ", ")
        }
    }

    /// Normal sets number 1, 2, 3… skipping warmup/drop/failure rows.
    private func normalSetNumber(for set: SetEntry) -> Int {
        var number = 0
        for candidate in sortedSets {
            if candidate.setType == .normal { number += 1 }
            if candidate.id == set.id { break }
        }
        return number
    }

    private func complete(_ set: SetEntry) {
        set.completedAt = .now
        set.markDirty()
        try? context.save()
        onSetCompleted()
    }

    private func addSet() {
        let last = sortedSets.last
        let newSet = SetEntry(
            index: (item.sets.map(\.index).max() ?? -1) + 1,
            weightKG: last?.weightKG ?? 20,
            reps: last?.reps ?? 8,
            setType: last?.setType == .warmup ? .normal : (last?.setType ?? .normal)
        )
        newSet.durationSec = last?.durationSec ?? (trackingKind == .weightReps ? 0 : 600)
        newSet.distanceM = last?.distanceM ?? 0
        newSet.speedKPH = last?.speedKPH ?? 0
        newSet.inclinePct = last?.inclinePct ?? 0
        item.sets.append(newSet)
        try? context.save()
        Haptics.light()
    }

    private func delete(_ set: SetEntry) {
        context.delete(set)
        // Reindex so numbering stays dense.
        for (index, remaining) in sortedSets.filter({ $0.id != set.id }).enumerated() {
            remaining.index = index
        }
        try? context.save()
    }
}

// MARK: - Set row

private struct SetRow: View {
    @Bindable var set: SetEntry
    let kind: ExerciseTrackingKind
    let normalNumber: Int
    let weightUnit: UnitPreference
    let distanceUnit: DistanceUnit
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            setTypeBadge

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    inputs
                }
            }

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(set.isCompleted ? Theme.Color.accent : Theme.Color.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(set.isCompleted)
            .frame(width: 36, height: 44)
            .accessibilityLabel("Mark set complete")
            .accessibilityValue(set.isCompleted ? "Completed" : "Not completed")
        }
        .opacity(set.isCompleted ? 0.6 : 1)
    }

    /// The number/W/D/F chip. Tapping opens the type menu — one control
    /// for both reading and changing the set type.
    private var setTypeBadge: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    set.setType = type
                    set.markDirty()
                } label: {
                    Label(typeLabel(type), systemImage: set.setType == type ? "checkmark" : "")
                }
            }
            Divider()
            Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Text(set.setType.badge ?? "\(normalNumber)")
                .font(Theme.Font.numeral(14, weight: .bold))
                .foregroundStyle(badgeForeground)
                .frame(width: 30, height: 30)
                .background(badgeBackground, in: Circle())
        }
        .accessibilityLabel("Set type: \(typeLabel(set.setType))")
    }

    private func typeLabel(_ type: SetType) -> String {
        switch type {
        case .warmup: return "Warm-up"
        case .normal: return "Normal set"
        case .drop: return "Drop set"
        case .failure: return "To failure"
        }
    }

    private var badgeForeground: SwiftUI.Color {
        switch set.setType {
        case .normal: return Theme.Color.textPrimary
        case .warmup: return Theme.Color.warning
        case .drop: return .purple
        case .failure: return Theme.Color.error
        }
    }

    private var badgeBackground: SwiftUI.Color {
        switch set.setType {
        case .normal: return Theme.Color.surface2
        case .warmup: return Theme.Color.warning.opacity(0.15)
        case .drop: return SwiftUI.Color.purple.opacity(0.15)
        case .failure: return Theme.Color.error.opacity(0.15)
        }
    }

    // MARK: inputs per tracking kind

    @ViewBuilder
    private var inputs: some View {
        switch kind {
        case .weightReps:
            weightStepper
            Text("×").foregroundStyle(Theme.Color.textTertiary).accessibilityHidden(true)
            repsStepper
        case .bodyweightReps:
            repsStepper
            if set.weightKG > 0 {
                Text("+").foregroundStyle(Theme.Color.textTertiary).accessibilityHidden(true)
                weightStepper
            } else {
                Button("+ weight") {
                    set.weightKG = weightUnit == .imperial ? Units.weightToKG(5, unit: .imperial) : 2.5
                    set.markDirty()
                }
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textTertiary)
            }
        case .timeOnly:
            durationStepper
        case .cardioSpeedIncline:
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    durationStepper
                }
                HStack(spacing: Theme.Spacing.xs) {
                    speedStepper
                    inclineStepper
                }
            }
        case .cardioDistance:
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                durationStepper
                distanceStepper
            }
        }
    }

    private var weightStepper: some View {
        CompactStepper(
            value: Binding(
                get: { Units.displayWeight(set.weightKG, unit: weightUnit) },
                set: { set.weightKG = Units.weightToKG($0, unit: weightUnit); set.markDirty() }
            ),
            step: weightUnit == .imperial ? 5 : 2.5,
            label: "weight"
        ) { String(format: "%g", ($0 * 2).rounded() / 2) }
    }

    private var repsStepper: some View {
        CompactStepper(
            value: Binding(
                get: { Double(set.reps) },
                set: { set.reps = Int($0); set.markDirty() }
            ),
            step: 1,
            label: "reps"
        )
    }

    private var durationStepper: some View {
        CompactStepper(
            value: Binding(
                get: { Double(set.durationSec) / 60 },
                set: { set.durationSec = Int($0 * 60); set.markDirty() }
            ),
            step: 1,
            label: "minutes"
        ) { "\(Int($0))min" }
    }

    private var speedStepper: some View {
        CompactStepper(
            value: Binding(
                get: { Units.displaySpeed(set.speedKPH, unit: distanceUnit) },
                set: { set.speedKPH = Units.speedToKPH($0, unit: distanceUnit); set.markDirty() }
            ),
            step: 0.5,
            label: "speed"
        ) { String(format: "%.1f%@", $0, Units.speedLabel(distanceUnit)) }
    }

    private var inclineStepper: some View {
        CompactStepper(
            value: Binding(
                get: { set.inclinePct },
                set: { set.inclinePct = $0; set.markDirty() }
            ),
            step: 0.5,
            label: "incline"
        ) { String(format: "%.1f%%", $0) }
    }

    private var distanceStepper: some View {
        CompactStepper(
            value: Binding(
                get: { Units.displayDistance(set.distanceM, unit: distanceUnit) },
                set: { set.distanceM = Units.distanceToMeters($0, unit: distanceUnit); set.markDirty() }
            ),
            step: 0.25,
            label: "distance"
        ) { String(format: "%.2f%@", $0, Units.distanceLabel(distanceUnit)) }
    }
}
