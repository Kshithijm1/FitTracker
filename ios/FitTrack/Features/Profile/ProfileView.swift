import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [UserProfile]
    @Query private var goalsList: [Goals]

    private var profile: UserProfile {
        if let existing = profiles.first { return existing }
        let created = UserProfile(displayName: "You")
        context.insert(created)
        try? context.save()
        return created
    }

    private var goals: Goals {
        if let existing = goalsList.first { return existing }
        let created = Goals()
        context.insert(created)
        try? context.save()
        return created
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    LabeledContent("Name", value: profile.displayName)
                    Picker("Units", selection: Bindable(profile).unitPreference) {
                        Text("Imperial (lb)").tag(UnitPreference.imperial)
                        Text("Metric (kg)").tag(UnitPreference.metric)
                    }
                }

                Section("Daily goals") {
                    Stepper("Calories: \(goals.calorieTarget)", value: Bindable(goals).calorieTarget, in: 1000...5000, step: 50)
                    Stepper("Protein: \(goals.proteinG)g", value: Bindable(goals).proteinG, in: 0...400, step: 5)
                    Stepper("Carbs: \(goals.carbsG)g", value: Bindable(goals).carbsG, in: 0...600, step: 5)
                    Stepper("Fat: \(goals.fatG)g", value: Bindable(goals).fatG, in: 0...200, step: 5)
                    Stepper("Water: \(goals.waterML) mL", value: Bindable(goals).waterML, in: 0...5000, step: 250)
                    Stepper("Steps: \(goals.stepTarget)", value: Bindable(goals).stepTarget, in: 0...30000, step: 500)
                }

                Section("Security") {
                    Toggle("Face ID app lock", isOn: Bindable(container.appLock).isEnabled)
                    Text("Sign-in, sync, and account deletion arrive with the backend in Phase 2.")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .navigationTitle("Profile")
            .onChange(of: profile.unitPreference) { _, _ in profile.markDirty(); try? context.save() }
            .onChange(of: goals.calorieTarget) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.proteinG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.carbsG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.fatG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.waterML) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.stepTarget) { _, _ in goals.markDirty(); try? context.save() }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppContainer())
        .modelContainer(for: [UserProfile.self, Goals.self], inMemory: true)
}
