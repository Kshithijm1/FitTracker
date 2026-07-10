import SwiftUI
import SwiftData

/// Everything about *you* that shapes the app: personal stats, every daily
/// goal, units for every measurement, training preferences, connected
/// apps, AI memory controls, account & security.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [UserProfile]
    @Query private var goalsList: [Goals]

    @AppStorage("restTimerSeconds") private var restTimerSeconds = 90
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system

    @State private var showingSignIn = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEraseMemoryConfirmation = false
    @State private var deleteError: String?
    @State private var showingHealthKitPermission = false
    @State private var memoryCount = 0

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

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        NavigationStack {
            Form {
                personalSection
                appearanceSection
                goalsSection
                unitsSection
                trainingSection
                aiSection
                accountSection
                healthSection
                securitySection
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSignIn) {
                SignInView()
            }
            .sheet(isPresented: $showingHealthKitPermission) {
                HealthKitPermissionView()
            }
            .alert("Delete your account?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and synced data from the server. Data already on this device is kept locally.")
            }
            .alert("Erase coach memory?", isPresented: $showingEraseMemoryConfirmation) {
                Button("Erase everything", role: .destructive) {
                    container.memory.eraseAll()
                    memoryCount = 0
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The coach forgets everything it has learned about you. Your logged data is not affected.")
            }
            .onAppear { memoryCount = container.memory.count }
            // Persist + mark dirty on every tracked change.
            .onChange(of: profile.unitPreference) { _, _ in saveProfile() }
            .onChange(of: profile.displayName) { _, _ in saveProfile() }
            .onChange(of: profile.sexRaw) { _, _ in saveProfile() }
            .onChange(of: profile.birthYear) { _, _ in saveProfile() }
            .onChange(of: profile.heightCM) { _, _ in saveProfile() }
            .onChange(of: profile.volumeUnitRaw) { _, _ in saveProfile() }
            .onChange(of: profile.distanceUnitRaw) { _, _ in saveProfile() }
            .onChange(of: goals.calorieTarget) { _, _ in saveGoals() }
            .onChange(of: goals.proteinG) { _, _ in saveGoals() }
            .onChange(of: goals.carbsG) { _, _ in saveGoals() }
            .onChange(of: goals.fatG) { _, _ in saveGoals() }
            .onChange(of: goals.waterML) { _, _ in saveGoals() }
            .onChange(of: goals.stepTarget) { _, _ in saveGoals() }
            .onChange(of: goals.sleepMinutesTarget) { _, _ in saveGoals() }
            .onChange(of: goals.weightGoalKG) { _, _ in saveGoals() }
            .onChange(of: goals.goalDate) { _, _ in saveGoals() }
        }
    }

    // MARK: - Sections

    private var personalSection: some View {
        Section("About you") {
            TextField("Name", text: Bindable(profile).displayName)

            Picker("Sex", selection: Bindable(profile).sexRaw) {
                Text("Female").tag(BiologicalSex.female.rawValue)
                Text("Male").tag(BiologicalSex.male.rawValue)
                Text("Not specified").tag(BiologicalSex.unspecified.rawValue)
            }

            Picker("Birth year", selection: Bindable(profile).birthYear) {
                Text("Not set").tag(0)
                ForEach(((currentYear - 100)...(currentYear - 13)).reversed(), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }

            Picker("Height", selection: Binding(
                get: { Int(profile.heightCM.rounded()) },
                set: { profile.heightCM = Double($0) }
            )) {
                Text("Not set").tag(0)
                ForEach(120...220, id: \.self) { cm in
                    Text(Units.formatHeight(Double(cm), unit: profile.unitPreference)).tag(cm)
                }
            }

            Picker("Main goal", selection: Bindable(profile).fitnessGoalRaw) {
                ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                    Text(goal.label).tag(goal.rawValue)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        }
    }

    private var goalsSection: some View {
        Section("Daily goals") {
            Stepper("Calories: \(goals.calorieTarget)", value: Bindable(goals).calorieTarget, in: 1000...6000, step: 50)
            Stepper("Protein: \(goals.proteinG)g", value: Bindable(goals).proteinG, in: 0...400, step: 5)
            Stepper("Carbs: \(goals.carbsG)g", value: Bindable(goals).carbsG, in: 0...600, step: 5)
            Stepper("Fat: \(goals.fatG)g", value: Bindable(goals).fatG, in: 0...200, step: 5)
            Stepper(
                "Water: \(Units.formatVolume(goals.waterML, unit: profile.volumeUnit))",
                value: Bindable(goals).waterML, in: 0...6000, step: 250
            )
            Stepper("Steps: \(goals.stepTarget.formatted())", value: Bindable(goals).stepTarget, in: 0...40000, step: 500)
            Stepper(
                "Sleep: \(goals.sleepMinutesTarget / 60)h \(goals.sleepMinutesTarget % 60 == 0 ? "" : "30m")",
                value: Bindable(goals).sleepMinutesTarget, in: 300...720, step: 30
            )

            // Goal weight in the user's display unit.
            HStack {
                Text("Goal weight")
                Spacer()
                TextField(
                    "None",
                    value: Binding(
                        get: { goals.weightGoalKG.map { (Units.displayWeight($0, unit: profile.unitPreference) * 10).rounded() / 10 } },
                        set: { newValue in
                            goals.weightGoalKG = newValue.map { Units.weightToKG($0, unit: profile.unitPreference) }
                        }
                    ),
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                Text(Units.weightLabel(profile.unitPreference))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            if goals.weightGoalKG != nil {
                DatePicker(
                    "Target date",
                    selection: Binding(
                        get: { goals.goalDate ?? Calendar.current.date(byAdding: .month, value: 3, to: .now)! },
                        set: { goals.goalDate = $0 }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            Picker("Weight", selection: Bindable(profile).unitPreference) {
                Text("Pounds (lb)").tag(UnitPreference.imperial)
                Text("Kilograms (kg)").tag(UnitPreference.metric)
            }
            Picker("Volume", selection: Bindable(profile).volumeUnitRaw) {
                Text("Milliliters (ml)").tag(VolumeUnit.milliliters.rawValue)
                Text("Fluid ounces (fl oz)").tag(VolumeUnit.fluidOunces.rawValue)
            }
            Picker("Distance", selection: Bindable(profile).distanceUnitRaw) {
                Text("Kilometers (km)").tag(DistanceUnit.kilometers.rawValue)
                Text("Miles (mi)").tag(DistanceUnit.miles.rawValue)
            }
        }
    }

    private var trainingSection: some View {
        Section("Training") {
            Stepper(
                "Rest timer: \(restTimerSeconds)s",
                value: $restTimerSeconds, in: 15...600, step: 15
            )
            Text("Starts automatically when you check off a set.")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var aiSection: some View {
        Section("AI Coach & privacy") {
            LabeledContent("Coach memory", value: "\(memoryCount) notes")
            Button("Erase coach memory", role: .destructive) {
                showingEraseMemoryConfirmation = true
            }
            Text("Memory lives on this device only. Questions you ask the coach include relevant notes; nothing is stored server-side.")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var accountSection: some View {
        Section("Account & Sync") {
            if let user = container.auth.currentUser {
                LabeledContent("Signed in as", value: user.email ?? user.displayName)
                Button("Sync now") {
                    Task { await container.syncEngine.syncNow() }
                }
                if container.syncEngine.isSyncing {
                    Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                } else if let lastSyncedAt = container.syncEngine.lastSyncedAt {
                    Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Button("Sign out") {
                    Task { await container.auth.signOut() }
                }
                Button("Delete account", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } else {
                Button("Sign in to enable sync & cloud AI") {
                    showingSignIn = true
                }
                Text("FitTrack works fully offline without an account. Signing in adds cross-device sync and server-side AI (photo logging, recipe import) on devices without on-device AI.")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            if let deleteError {
                Text(deleteError)
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.error)
            }
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        if container.healthKit.isHealthDataAvailable {
            Section("Connected apps") {
                Button(container.healthKit.hasRequestedAccess ? "Refresh from Apple Health" : "Connect Apple Health") {
                    if container.healthKit.hasRequestedAccess {
                        Task { await container.healthKit.refreshToday() }
                    } else {
                        showingHealthKitPermission = true
                    }
                }
                Text("Read-only: steps and sleep. Never synced to FitTrack's servers. Fitbit/Garmin data arrives via their Apple Health integrations.")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle("Face ID app lock", isOn: Bindable(container.appLock).isEnabled)
        }
    }

    // MARK: - Persistence

    private func saveProfile() {
        profile.markDirty()
        try? context.save()
    }

    private func saveGoals() {
        goals.markDirty()
        try? context.save()
    }

    private func deleteAccount() async {
        do {
            try await container.auth.deleteAccount()
        } catch {
            deleteError = "Couldn't delete your account. Check your connection and try again."
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppContainer())
        .modelContainer(for: [UserProfile.self, Goals.self], inMemory: true)
}
