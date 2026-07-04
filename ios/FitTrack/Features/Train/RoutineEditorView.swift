import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.position) private var routines: [Routine]
    @Query private var allExercises: [Exercise]

    @State private var name = ""
    @State private var items: [RoutineItem] = []
    @State private var showingExercisePicker = false

    private func exerciseName(for id: UUID) -> String {
        allExercises.first { $0.id == id }?.name ?? "Exercise"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Routine name", text: $name)
                }

                Section("Exercises") {
                    ForEach(items) { item in
                        Text(exerciseName(for: item.exerciseID))
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                    Button("Add exercise") {
                        showingExercisePicker = true
                    }
                }
            }
            .navigationTitle("New Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    items.append(RoutineItem(exerciseID: exercise.id, position: items.count))
                }
            }
        }
    }

    private func save() {
        let routine = Routine(name: name, position: routines.count)
        routine.items = items
        context.insert(routine)
        try? context.save()
        dismiss()
    }
}

extension RoutineItem: Identifiable {}

#Preview {
    RoutineEditorView()
        .modelContainer(for: [Routine.self], inMemory: true)
}
