import SwiftUI
import SwiftData

extension Exercise: Identifiable {}

/// Full-library exercise search with muscle-group chips and an equipment
/// filter. No match? The typed name becomes a custom exercise in one tap.
struct ExercisePickerView: View {
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var muscleFilter: String?
    @State private var equipmentFilter: String?

    private static let muscleGroups = [
        "chest", "back", "shoulders", "biceps", "triceps",
        "quads", "hamstrings", "glutes", "core", "calves", "forearms", "cardio",
    ]

    private var equipmentOptions: [String] {
        Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            guard exercise.archivedAt == nil, exercise.deletedAt == nil else { return false }
            if let muscleFilter, !exercise.muscleGroups.contains(muscleFilter) { return false }
            if let equipmentFilter, exercise.equipment != equipmentFilter { return false }
            if !searchText.isEmpty, !exercise.name.localizedCaseInsensitiveContains(searchText) { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                muscleChips

                List {
                    ForEach(filtered) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            ExerciseRow(exercise: exercise)
                        }
                    }

                    if filtered.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            createCustomExercise()
                        } label: {
                            Label("Create \"\(searchText)\"", systemImage: "plus.circle.fill")
                                .foregroundStyle(Theme.Color.accent)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("All equipment") { equipmentFilter = nil }
                        Divider()
                        ForEach(equipmentOptions, id: \.self) { equipment in
                            Button {
                                equipmentFilter = equipment
                            } label: {
                                Label(equipment.capitalized, systemImage: equipmentFilter == equipment ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: equipmentFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter by equipment")
                }
            }
        }
    }

    private var muscleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                chip(title: "All", isOn: muscleFilter == nil) { muscleFilter = nil }
                ForEach(Self.muscleGroups, id: \.self) { muscle in
                    chip(title: muscle.capitalized, isOn: muscleFilter == muscle) {
                        muscleFilter = muscleFilter == muscle ? nil : muscle
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.caption13)
                .foregroundStyle(isOn ? Theme.Color.onAccent : Theme.Color.textPrimary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(isOn ? Theme.Color.accent : Theme.Color.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func createCustomExercise() {
        let name = searchText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(
            name: name,
            muscleGroups: muscleFilter.map { [$0] } ?? [],
            equipment: equipmentFilter ?? "other",
            isCustom: true
        )
        context.insert(exercise)
        try? context.save()
        onPick(exercise)
        dismiss()
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    private var kindIcon: String {
        switch exercise.trackingKind {
        case .weightReps: return "dumbbell"
        case .bodyweightReps: return "figure.strengthtraining.functional"
        case .timeOnly: return "timer"
        case .cardioSpeedIncline, .cardioDistance: return "figure.run"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: kindIcon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(exercise.name)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(
                    (exercise.muscleGroups.prefix(2).map(\.capitalized) + [exercise.equipment.capitalized])
                        .joined(separator: " · ")
                )
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            if exercise.isCustom {
                Text("Custom")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }
}
