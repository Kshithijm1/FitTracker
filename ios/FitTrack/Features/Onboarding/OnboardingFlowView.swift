import SwiftUI
import SwiftData

/// The goal questionnaire: one focused question per screen, big touch
/// targets, a thin progress bar, always skippable forward motion. Answers
/// feed `PlanCalculator` (instant, offline) and the AI coach's memory.
struct OnboardingFlowView: View {
    let onFinished: () -> Void

    @Environment(AppContainer.self) private var container

    @State private var step: Step = .name
    @State private var answers = Answers()

    enum Step: Int, CaseIterable {
        case name, body, activity, goal, target, training, diet, reveal
    }

    struct Answers {
        var name = ""
        var sex: BiologicalSex = .unspecified
        var birthYear = Calendar.current.component(.year, from: .now) - 25
        var unitPreference: UnitPreference = .imperial
        var heightCM: Double = 173
        var weightKG: Double = 75
        var activityLevel: ActivityLevel = .moderate
        var goal: FitnessGoal = .loseWeight
        var goalWeightKG: Double = 70
        var goalDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: .now) ?? .now
        var hasTargetDate = true
        var workoutDaysPerWeek = 3
        var dietRestrictions: Set<String> = []

        var wantsWeightTarget: Bool {
            goal == .loseWeight || goal == .buildMuscle || goal == .recomposition
        }

        var planInput: PlanCalculator.Input {
            PlanCalculator.Input(
                sex: sex,
                age: max(Calendar.current.component(.year, from: .now) - birthYear, 13),
                heightCM: heightCM,
                weightKG: weightKG,
                activityLevel: activityLevel,
                goal: goal,
                goalWeightKG: wantsWeightTarget ? goalWeightKG : nil,
                goalDate: wantsWeightTarget && hasTargetDate ? goalDate : nil,
                workoutDaysPerWeek: workoutDaysPerWeek,
                dietRestrictions: Array(dietRestrictions).sorted()
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $step) {
                NameStep(answers: $answers, onNext: advance).tag(Step.name)
                BodyStep(answers: $answers, onNext: advance).tag(Step.body)
                ActivityStep(answers: $answers, onNext: advance).tag(Step.activity)
                GoalStep(answers: $answers, onNext: advance).tag(Step.goal)
                TargetStep(answers: $answers, onNext: advance).tag(Step.target)
                TrainingStep(answers: $answers, onNext: advance).tag(Step.training)
                DietStep(answers: $answers, onNext: advance).tag(Step.diet)
                PlanRevealView(input: answers.planInput, displayName: answers.name, answers: answers, onFinished: onFinished)
                    .tag(Step.reveal)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: step)
        }
        .background(Theme.Color.background)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if step != .name && step != .reveal {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(Theme.Color.accent)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
    }

    private func advance() {
        Haptics.light()
        var next = Step(rawValue: step.rawValue + 1) ?? .reveal
        // Skip the weight-target step for goals it doesn't apply to.
        if next == .target && !answers.wantsWeightTarget {
            next = .training
        }
        step = next
    }

    private func goBack() {
        var previous = Step(rawValue: step.rawValue - 1) ?? .name
        if previous == .target && !answers.wantsWeightTarget {
            previous = .goal
        }
        step = previous
    }
}

// MARK: - Shared step scaffolding

/// Consistent layout for every question screen: title, optional subtitle,
/// content, pinned continue button.
private struct StepScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    var continueDisabled = false
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.display28)
                    .foregroundStyle(Theme.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.body17)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .padding(.top, Theme.Spacing.lg)

            ScrollView {
                content()
            }
            .scrollBounceBehavior(.basedOnSize)

            Button(action: onNext) {
                Text("Continue")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        continueDisabled ? Theme.Color.surface2 : Theme.Color.accent,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    )
            }
            .disabled(continueDisabled)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

/// A large tappable option row with selection state — the standard control
/// across onboarding (one-handed, glanceable, no tiny targets).
private struct OptionRow: View {
    let title: String
    var subtitle: String?
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Theme.Color.accent : Theme.Color.textSecondary)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.Color.accent : Theme.Color.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(isSelected ? Theme.Color.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Steps

private struct NameStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        StepScaffold(
            title: "What should we call you?",
            continueDisabled: answers.name.trimmingCharacters(in: .whitespaces).isEmpty,
            onNext: onNext
        ) {
            TextField("Your name", text: $answers.name)
                .font(Theme.Font.title22)
                .focused($focused)
                .textContentType(.givenName)
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .submitLabel(.continue)
                .onSubmit { if !answers.name.isEmpty { onNext() } }
                .task { focused = true }
        }
    }
}

private struct BodyStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        StepScaffold(
            title: "About you",
            subtitle: "Used only to calculate your calorie needs.",
            onNext: onNext
        ) {
            VStack(spacing: Theme.Spacing.md) {
                Picker("Units", selection: $answers.unitPreference) {
                    Text("lb / ft").tag(UnitPreference.imperial)
                    Text("kg / cm").tag(UnitPreference.metric)
                }
                .pickerStyle(.segmented)

                labeledCard("Sex") {
                    Picker("Sex", selection: $answers.sex) {
                        Text("Female").tag(BiologicalSex.female)
                        Text("Male").tag(BiologicalSex.male)
                        Text("Prefer not to say").tag(BiologicalSex.unspecified)
                    }
                    .pickerStyle(.segmented)
                }

                labeledCard("Year of birth") {
                    Picker("Year of birth", selection: $answers.birthYear) {
                        ForEach(((currentYear - 100)...(currentYear - 13)).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 96)
                }

                labeledCard("Height") {
                    HeightPicker(heightCM: $answers.heightCM, unit: answers.unitPreference)
                }

                labeledCard("Current weight") {
                    WeightField(weightKG: $answers.weightKG, unit: answers.unitPreference)
                }
            }
        }
    }

    private func labeledCard(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}

/// Height in cm (metric wheel) or ft+in (two wheels), always stored as cm.
private struct HeightPicker: View {
    @Binding var heightCM: Double
    let unit: UnitPreference

    var body: some View {
        if unit == .metric {
            Picker("Height", selection: Binding(
                get: { Int(heightCM.rounded()) },
                set: { heightCM = Double($0) }
            )) {
                ForEach(120...220, id: \.self) { cm in
                    Text("\(cm) cm").tag(cm)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 96)
        } else {
            let totalInches = heightCM / 2.54
            HStack(spacing: 0) {
                Picker("Feet", selection: Binding(
                    get: { Int(totalInches / 12) },
                    set: { heightCM = (Double($0) * 12 + Double(Int(totalInches) % 12)) * 2.54 }
                )) {
                    ForEach(4...7, id: \.self) { feet in
                        Text("\(feet) ft").tag(feet)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Inches", selection: Binding(
                    get: { Int(totalInches.rounded()) % 12 },
                    set: { heightCM = (Double(Int(totalInches / 12)) * 12 + Double($0)) * 2.54 }
                )) {
                    ForEach(0...11, id: \.self) { inches in
                        Text("\(inches) in").tag(inches)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 96)
        }
    }
}

/// Weight entry field that displays/accepts the user's unit, stores kg.
private struct WeightField: View {
    @Binding var weightKG: Double
    let unit: UnitPreference

    var body: some View {
        HStack {
            TextField("Weight", value: Binding(
                get: { (Units.displayWeight(weightKG, unit: unit) * 10).rounded() / 10 },
                set: { weightKG = Units.weightToKG($0, unit: unit) }
            ), format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .font(Theme.Font.numeral(28))
            .foregroundStyle(Theme.Color.textPrimary)

            Text(Units.weightLabel(unit))
                .font(Theme.Font.body17)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

private struct ActivityStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    var body: some View {
        StepScaffold(
            title: "How active is your typical day?",
            subtitle: "Outside of workouts you log here.",
            onNext: onNext
        ) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    OptionRow(
                        title: level.label,
                        subtitle: level.detail,
                        isSelected: answers.activityLevel == level
                    ) {
                        answers.activityLevel = level
                    }
                }
            }
        }
    }
}

private struct GoalStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    var body: some View {
        StepScaffold(title: "What's your main goal?", onNext: onNext) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    OptionRow(
                        title: goal.label,
                        icon: goal.icon,
                        isSelected: answers.goal == goal
                    ) {
                        answers.goal = goal
                        if goal == .buildMuscle && answers.goalWeightKG < answers.weightKG {
                            answers.goalWeightKG = answers.weightKG + 4
                        } else if goal == .loseWeight && answers.goalWeightKG > answers.weightKG {
                            answers.goalWeightKG = max(answers.weightKG - 5, 40)
                        }
                    }
                }
            }
        }
    }
}

private struct TargetStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    var body: some View {
        StepScaffold(
            title: "Set your target",
            subtitle: "We'll pace it safely — you can change this anytime.",
            onNext: onNext
        ) {
            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Goal weight")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                    WeightField(weightKG: $answers.goalWeightKG, unit: answers.unitPreference)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Toggle("Target date", isOn: $answers.hasTargetDate)
                        .font(Theme.Font.bodyEmphasized17)
                        .tint(Theme.Color.accent)
                    if answers.hasTargetDate {
                        DatePicker(
                            "By when?",
                            selection: $answers.goalDate,
                            in: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: .now)!...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Theme.Color.accent)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
        }
    }
}

private struct TrainingStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    var body: some View {
        StepScaffold(
            title: "How often can you train?",
            subtitle: "Days per week — be honest, not ambitious. We'll build routines to match.",
            onNext: onNext
        ) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(1...7, id: \.self) { days in
                    Button {
                        answers.workoutDaysPerWeek = days
                        Haptics.light()
                    } label: {
                        Text("\(days)")
                            .font(Theme.Font.numeral(20))
                            .foregroundStyle(
                                answers.workoutDaysPerWeek == days
                                    ? Theme.Color.onAccent : Theme.Color.textPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                answers.workoutDaysPerWeek == days
                                    ? Theme.Color.accent : Theme.Color.surface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.small)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DietStep: View {
    @Binding var answers: OnboardingFlowView.Answers
    let onNext: () -> Void

    private static let options = [
        "Vegetarian", "Vegan", "Gluten-free", "Dairy-free",
        "Halal", "Kosher", "Low-carb", "No restrictions",
    ]

    var body: some View {
        StepScaffold(
            title: "Any eating preferences?",
            subtitle: "Meal ideas and diet tips will respect these.",
            onNext: onNext
        ) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(Self.options, id: \.self) { option in
                    OptionRow(
                        title: option,
                        isSelected: option == "No restrictions"
                            ? answers.dietRestrictions.isEmpty
                            : answers.dietRestrictions.contains(option)
                    ) {
                        if option == "No restrictions" {
                            answers.dietRestrictions.removeAll()
                        } else if answers.dietRestrictions.contains(option) {
                            answers.dietRestrictions.remove(option)
                        } else {
                            answers.dietRestrictions.insert(option)
                        }
                    }
                }
            }
        }
    }
}
