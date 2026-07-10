import SwiftUI
import SwiftData

extension RoutineItem: Identifiable {}

/// Create or edit a routine: name, exercises (drag to reorder, swipe to
/// delete), per-exercise target sets/reps. Editing writes through to the
/// existing routine; creating stages locally until Save.
struct RoutineEditorView: View {
    /// nil = creating a new routine.
    var routine: Routine?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.position) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var name = ""
    @State private var drafts: [Draft] = []
    @State private var showingExercisePicker = false

    /// Value-type staging row so Cancel never leaves half-edited models.
    struct Draft: Identifiable {
        let id = UUID()
        var exerciseID: UUID
        var targetSets: Int
        var targetReps: Int
    }

    private var exercisesByID: [UUID: Exercise] {
        Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name (e.g. Push Day)", text: $name)
                }

                Section("Exercises") {
                    if drafts.isEmpty {
                        Text("Add exercises below — drag to reorder them later.")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(exercisesByID[draft.exerciseID]?.name ?? "Exercise")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                            HStack {
                                Stepper("\(draft.targetSets) sets", value: $draft.targetSets, in: 1...10)
                                    .font(Theme.Font.caption13)
                            }
                            if showsRepTargets(draft) {
                                Stepper("\(draft.targetReps) reps", value: $draft.targetReps, in: 1...50)
                                    .font(Theme.Font.caption13)
                            }
                        }
                    }
                    .onMove { from, to in
                        drafts.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        drafts.remove(atOffsets: offsets)
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.Color.accent)
                    }
                }
            }
            .environment(\.editMode, .constant(.active)) // always-on drag handles
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || drafts.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    drafts.append(Draft(exerciseID: exercise.id, targetSets: 3, targetReps: 8))
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func showsRepTargets(_ draft: Draft) -> Bool {
        let kind = exercisesByID[draft.exerciseID]?.trackingKind ?? .weightReps
        return kind == .weightReps || kind == .bodyweightReps
    }

    private func loadExisting() {
        guard let routine, drafts.isEmpty, name.isEmpty else { return }
        name = routine.name
        drafts = routine.items
            .sorted { $0.position < $1.position }
            .map { Draft(exerciseID: $0.exerciseID, targetSets: $0.targetSets, targetReps: $0.targetReps) }
    }

    private func save() {
        let target: Routine
        if let routine {
            target = routine
            target.name = name
            // Replace items wholesale — simplest correct reorder/edit.
            for item in target.items { context.delete(item) }
            target.items.removeAll()
            target.markDirty()
        } else {
            target = Routine(name: name, position: routines.count)
            context.insert(target)
        }
        for (position, draft) in drafts.enumerated() {
            target.items.append(RoutineItem(
                exerciseID: draft.exerciseID,
                position: position,
                targetSets: draft.targetSets,
                targetReps: draft.targetReps
            ))
        }
        try? context.save()
        Haptics.light()
        dismiss()
    }
}

#Preview {
    RoutineEditorView()
        .modelContainer(for: [Routine.self], inMemory: true)
}
