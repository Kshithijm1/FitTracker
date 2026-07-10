import SwiftUI
import SwiftData

/// Final onboarding screen: the computed plan, revealed as a small set of
/// cards — targets, pace, starter routines, diet pointers — with one
/// button. Saving writes the profile + goals, creates the routines, and
/// seeds the coach's long-term memory with everything learned.
struct PlanRevealView: View {
    let input: PlanCalculator.Input
    let displayName: String
    let answers: OnboardingFlowView.Answers
    let onFinished: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container

    private var plan: PlanCalculator.Plan { PlanCalculator.makePlan(from: input) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Your plan is ready\(displayName.isEmpty ? "" : ", \(displayName)")")
                            .font(Theme.Font.display28)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(paceLine)
                            .font(Theme.Font.body17)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .padding(.top, Theme.Spacing.lg)

                    // Daily targets
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("Daily targets", systemImage: "target")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)

                            HStack {
                                TargetStat(value: "\(plan.calorieTarget)", label: "kcal")
                                TargetStat(value: "\(plan.proteinG)g", label: "protein")
                                TargetStat(value: "\(plan.carbsG)g", label: "carbs")
                                TargetStat(value: "\(plan.fatG)g", label: "fat")
                            }

                            Divider()

                            HStack {
                                TargetStat(value: Units.formatVolume(plan.waterML, unit: answers.unitPreference == .imperial ? .fluidOunces : .milliliters), label: "water")
                                TargetStat(value: plan.stepTarget.formatted(.number.notation(.compactName)), label: "steps")
                                TargetStat(value: "\(plan.sleepMinutes / 60)h", label: "sleep")
                            }
                        }
                    }

                    // Starter routines
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("Your starter routines", systemImage: "dumbbell.fill")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("Proven templates for \(input.workoutDaysPerWeek) days/week — ready in the Train tab.")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)

                            ForEach(plan.routines, id: \.name) { routine in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Color.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(routine.name)
                                            .font(Theme.Font.body17)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Text("\(routine.exerciseNames.count) exercises")
                                            .font(Theme.Font.caption13)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                    }
                                }
                            }
                        }
                    }

                    // Diet pointers
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("Nutrition pointers", systemImage: "fork.knife")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                            ForEach(plan.dietSuggestions.prefix(3), id: \.self) { tip in
                                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                    Text("•").foregroundStyle(Theme.Color.accent)
                                    Text(tip)
                                        .font(Theme.Font.caption13)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                            }
                        }
                    }

                    Text("Everything here is editable in Profile — and your coach adjusts with you as you log.")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            Button {
                saveAndFinish()
            } label: {
                Text("Start tracking")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private var paceLine: String {
        if plan.weeklyChangeKG < -0.01 {
            let perWeek = Units.formatWeight(abs(plan.weeklyChangeKG), unit: answers.unitPreference)
            return "Built to lose ~\(perWeek)/week — sustainable and muscle-sparing."
        } else if plan.weeklyChangeKG > 0.01 {
            let perWeek = Units.formatWeight(plan.weeklyChangeKG, unit: answers.unitPreference)
            return "Built to gain ~\(perWeek)/week — lean gains, minimal fat."
        }
        return "Built to fuel performance at your current weight."
    }

    private func saveAndFinish() {
        // Profile (upsert — reuse an existing row if one was created earlier).
        let profile = ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? []).first
            ?? {
                let created = UserProfile(displayName: displayName.isEmpty ? "You" : displayName)
                context.insert(created)
                return created
            }()
        profile.displayName = displayName.isEmpty ? profile.displayName : displayName
        profile.unitPreference = answers.unitPreference
        profile.sex = answers.sex
        profile.birthYear = answers.birthYear
        profile.heightCM = answers.heightCM
        profile.startingWeightKG = answers.weightKG
        profile.activityLevel = answers.activityLevel
        profile.fitnessGoal = answers.goal
        profile.workoutDaysPerWeek = answers.workoutDaysPerWeek
        profile.dietRestrictions = Array(answers.dietRestrictions).sorted()
        profile.hasCompletedOnboarding = true
        profile.markDirty()

        // Goals (upsert).
        let goals = ((try? context.fetch(FetchDescriptor<Goals>())) ?? []).first
            ?? {
                let created = Goals()
                context.insert(created)
                return created
            }()
        goals.calorieTarget = plan.calorieTarget
        goals.proteinG = plan.proteinG
        goals.carbsG = plan.carbsG
        goals.fatG = plan.fatG
        goals.waterML = plan.waterML
        goals.stepTarget = plan.stepTarget
        goals.sleepMinutesTarget = plan.sleepMinutes
        goals.weightGoalKG = answers.wantsWeightTarget ? answers.goalWeightKG : nil
        goals.goalDate = answers.wantsWeightTarget && answers.hasTargetDate ? answers.goalDate : nil
        goals.markDirty()

        // Starting weigh-in so trends begin today.
        context.insert(WeightEntry(weightKG: answers.weightKG))

        // Starter routines, resolved against the seeded exercise library.
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(allExercises.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let existingRoutines = (try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0
        for (offset, starter) in plan.routines.enumerated() {
            let routine = Routine(name: starter.name, position: existingRoutines + offset)
            for (position, exerciseName) in starter.exerciseNames.enumerated() {
                guard let exercise = byName[exerciseName] else { continue }
                routine.items.append(RoutineItem(exerciseID: exercise.id, position: position))
            }
            if !routine.items.isEmpty { context.insert(routine) }
        }

        try? context.save()

        // Seed the coach's memory with who this user is.
        let memory = container.memory
        memory.remember(
            "Onboarding: goal is \(answers.goal.label.lowercased()), " +
            "trains \(answers.workoutDaysPerWeek) days/week, activity level \(answers.activityLevel.label.lowercased()).",
            kind: "preference"
        )
        if !answers.dietRestrictions.isEmpty {
            memory.remember("Diet restrictions: \(answers.dietRestrictions.sorted().joined(separator: ", ")).", kind: "preference")
        }
        if answers.wantsWeightTarget {
            memory.remember(
                String(format: "Starting weight %.1fkg, goal weight %.1fkg.", answers.weightKG, answers.goalWeightKG),
                kind: "body"
            )
        }

        Haptics.success()
        onFinished()
    }
}

private struct TargetStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.numeral(20))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
