import Foundation

/// Turns onboarding answers into a complete, science-based starting plan:
/// calorie/macro/water/step/sleep targets plus named starter routines and
/// diet suggestions. Deterministic (Mifflin-St Jeor BMR → activity-scaled
/// TDEE → safe goal pacing) so onboarding works instantly and offline; the
/// AI coach can refine numbers later in conversation.
enum PlanCalculator {

    struct Input {
        var sex: BiologicalSex
        var age: Int
        var heightCM: Double
        var weightKG: Double
        var activityLevel: ActivityLevel
        var goal: FitnessGoal
        var goalWeightKG: Double?
        var goalDate: Date?
        var workoutDaysPerWeek: Int
        var dietRestrictions: [String]
    }

    struct Plan {
        var calorieTarget: Int
        var proteinG: Int
        var carbsG: Int
        var fatG: Int
        var waterML: Int
        var stepTarget: Int
        var sleepMinutes: Int
        var weeklyChangeKG: Double
        var routines: [StarterRoutine]
        var dietSuggestions: [String]
    }

    struct StarterRoutine {
        var name: String
        /// Exercise names matched against the seeded library at save time.
        var exerciseNames: [String]
    }

    static func makePlan(from input: Input) -> Plan {
        let bmr = mifflinStJeor(
            sex: input.sex, age: input.age,
            heightCM: input.heightCM, weightKG: input.weightKG
        )
        let tdee = bmr * input.activityLevel.tdeeMultiplier

        // Pace: honor the requested date but clamp to safe, evidence-backed
        // bounds (max ~1% bodyweight/week loss, ~0.35kg/week gain).
        var weeklyChangeKG = 0.0
        if let goalWeight = input.goalWeightKG, goalWeight > 0 {
            let totalChange = goalWeight - input.weightKG
            let weeks: Double
            if let date = input.goalDate {
                weeks = max(date.timeIntervalSinceNow / (7 * 86_400), 1)
            } else {
                weeks = 16
            }
            let requested = totalChange / weeks
            let maxLoss = -max(input.weightKG * 0.01, 0.25)
            weeklyChangeKG = min(max(requested, maxLoss), 0.35)
        } else {
            switch input.goal {
            case .loseWeight: weeklyChangeKG = -0.5
            case .buildMuscle: weeklyChangeKG = 0.25
            case .recomposition, .maintain, .improveEndurance: weeklyChangeKG = 0
            }
        }

        // 7700 kcal per kg of bodyweight change.
        let dailyDelta = weeklyChangeKG * 7700 / 7
        // Never below BMR — aggressive dates degrade to the safe floor.
        let calories = max(Int((tdee + dailyDelta).rounded()), Int(bmr.rounded()))

        // Protein by goal (g per kg bodyweight): cutting keeps more muscle
        // at higher intake; endurance needs less.
        let proteinPerKG: Double
        switch input.goal {
        case .loseWeight, .recomposition: proteinPerKG = 2.0
        case .buildMuscle: proteinPerKG = 1.8
        case .maintain: proteinPerKG = 1.6
        case .improveEndurance: proteinPerKG = 1.4
        }
        let proteinG = Int((proteinPerKG * input.weightKG).rounded())
        let fatG = Int((Double(calories) * 0.25 / 9).rounded())     // 25% of calories
        let carbsG = max(Int((Double(calories) - Double(proteinG) * 4 - Double(fatG) * 9) / 4), 0)

        let waterML = Int((input.weightKG * 33 / 250).rounded() * 250) // ~33ml/kg, rounded to glasses
        let stepTarget = input.goal == .loseWeight ? 10_000 : 8_000

        return Plan(
            calorieTarget: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            waterML: waterML,
            stepTarget: stepTarget,
            sleepMinutes: 480,
            weeklyChangeKG: weeklyChangeKG,
            routines: starterRoutines(goal: input.goal, daysPerWeek: input.workoutDaysPerWeek),
            dietSuggestions: dietSuggestions(goal: input.goal, restrictions: input.dietRestrictions)
        )
    }

    /// Mifflin-St Jeor — the most validated resting-energy equation.
    static func mifflinStJeor(sex: BiologicalSex, age: Int, heightCM: Double, weightKG: Double) -> Double {
        let base = 10 * weightKG + 6.25 * heightCM - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .unspecified: return base - 78 // midpoint
        }
    }

    // MARK: - Starter routines

    /// Named after what they train — proven templates (full-body for low
    /// frequency, upper/lower, push/pull/legs) matched to available days.
    static func starterRoutines(goal: FitnessGoal, daysPerWeek: Int) -> [StarterRoutine] {
        if goal == .improveEndurance {
            return [
                StarterRoutine(name: "Endurance Base · Intervals", exerciseNames: [
                    "Treadmill Run", "Rowing Machine", "Assault Bike",
                ]),
                StarterRoutine(name: "Full Body · Strength Support", exerciseNames: [
                    "Goblet Squat", "Dumbbell Bench Press", "Dumbbell Row", "Plank",
                ]),
            ]
        }

        switch daysPerWeek {
        case ..<3:
            return [
                StarterRoutine(name: "Full Body A · Compound Focus", exerciseNames: [
                    "Back Squat", "Barbell Bench Press", "Dumbbell Row", "Plank",
                ]),
                StarterRoutine(name: "Full Body B · Hinge & Pull", exerciseNames: [
                    "Romanian Deadlift", "Overhead Press", "Lat Pulldown", "Walking Lunge",
                ]),
            ]
        case 3...4:
            return [
                StarterRoutine(name: "Upper Body · Push & Pull", exerciseNames: [
                    "Barbell Bench Press", "Barbell Row", "Overhead Press",
                    "Lat Pulldown", "Dumbbell Curl", "Triceps Pushdown",
                ]),
                StarterRoutine(name: "Lower Body · Squat & Hinge", exerciseNames: [
                    "Back Squat", "Romanian Deadlift", "Leg Press",
                    "Leg Curl (Lying)", "Standing Calf Raise", "Plank",
                ]),
            ]
        default:
            return [
                StarterRoutine(name: "Push · Chest, Shoulders, Triceps", exerciseNames: [
                    "Barbell Bench Press", "Incline Dumbbell Bench Press",
                    "Overhead Press", "Lateral Raise", "Triceps Pushdown",
                ]),
                StarterRoutine(name: "Pull · Back & Biceps", exerciseNames: [
                    "Deadlift", "Lat Pulldown", "Seated Cable Row",
                    "Face Pull", "Dumbbell Curl",
                ]),
                StarterRoutine(name: "Legs · Quads, Glutes, Hamstrings", exerciseNames: [
                    "Back Squat", "Romanian Deadlift", "Leg Press",
                    "Leg Curl (Seated)", "Standing Calf Raise",
                ]),
            ]
        }
    }

    // MARK: - Diet suggestions

    static func dietSuggestions(goal: FitnessGoal, restrictions: [String]) -> [String] {
        var suggestions: [String] = []
        let restricted = Set(restrictions.map { $0.lowercased() })

        switch goal {
        case .loseWeight:
            suggestions.append("High-protein, high-volume eating: lean meats, eggs, greek yogurt, and lots of vegetables keep you full on fewer calories.")
            suggestions.append("Front-load protein at breakfast — it measurably reduces late-day snacking.")
        case .buildMuscle:
            suggestions.append("Eat protein every 3–4 hours (4+ feedings/day) to keep muscle protein synthesis elevated.")
            suggestions.append("Add calorie-dense whole foods around workouts: rice, oats, nut butters, whole milk.")
        case .recomposition:
            suggestions.append("Keep protein high on all days; on training days shift more carbs around your workout window.")
        case .maintain:
            suggestions.append("Aim for the plate method: half vegetables, a quarter lean protein, a quarter whole grains.")
        case .improveEndurance:
            suggestions.append("Carbs are your fuel: target most of them in the meals before and after long sessions.")
        }

        if restricted.contains("vegetarian") || restricted.contains("vegan") {
            suggestions.append("Plant proteins to rotate: lentils, tofu, tempeh, edamame, seitan — pair with a protein powder to hit your target easily.")
        }
        if restricted.contains("gluten-free") {
            suggestions.append("Naturally gluten-free carb staples: rice, potatoes, quinoa, corn tortillas, oats (certified GF).")
        }
        if restricted.contains("dairy-free") || restricted.contains("lactose intolerant") {
            suggestions.append("Swap dairy protein for soy/pea protein isolate and calcium-fortified plant milks.")
        }
        suggestions.append("Log meals as you eat them, not at day's end — logging accuracy is the single best predictor of hitting goals.")
        return suggestions
    }
}
