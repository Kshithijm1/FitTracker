import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [UserProfile]
    @Query private var goalsList: [Goals]

    @State private var showingSignIn = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showingHealthKitPermission = false

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
                        Button("Sign in to enable sync") {
                            showingSignIn = true
                        }
                        Text("FitTrack works fully offline without an account. Signing in adds cross-device sync.")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    if let deleteError {
                        Text(deleteError)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.error)
                    }
                }

                if container.healthKit.isHealthDataAvailable {
                    Section("Apple Health") {
                        Button(container.healthKit.hasRequestedAccess ? "Refresh from Health" : "Connect Apple Health") {
                            if container.healthKit.hasRequestedAccess {
                                Task { await container.healthKit.refreshToday() }
                            } else {
                                showingHealthKitPermission = true
                            }
                        }
                        Text("Read-only: steps and sleep. Never synced to FitTrack's servers.")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }

                Section("Security") {
                    Toggle("Face ID app lock", isOn: Bindable(container.appLock).isEnabled)
                }
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
            .onChange(of: profile.unitPreference) { _, _ in profile.markDirty(); try? context.save() }
            .onChange(of: goals.calorieTarget) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.proteinG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.carbsG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.fatG) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.waterML) { _, _ in goals.markDirty(); try? context.save() }
            .onChange(of: goals.stepTarget) { _, _ in goals.markDirty(); try? context.save() }
        }
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
