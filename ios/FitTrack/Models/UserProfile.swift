import Foundation
import SwiftData

enum UnitPreference: String, Codable {
    case imperial // lb
    case metric   // kg
}

/// Fluid-volume display units (water, drinks).
enum VolumeUnit: String, Codable, CaseIterable {
    case milliliters, fluidOunces
}

/// Distance display units (cardio sets).
enum DistanceUnit: String, Codable, CaseIterable {
    case kilometers, miles
}

enum BiologicalSex: String, Codable, CaseIterable {
    case female, male, unspecified
}

/// Self-reported day-to-day activity outside deliberate exercise; the
/// multiplier feeds TDEE in `PlanCalculator`.
enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary, light, moderate, active, veryActive

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Light exercise 1–2 days/week"
        case .moderate: return "Exercise 3–4 days/week"
        case .active: return "Exercise 5–6 days/week"
        case .veryActive: return "Hard training daily or physical job"
        }
    }

    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

/// Primary goal chosen during onboarding; drives the calorie delta sign
/// and the starter routines/diet suggestions.
enum FitnessGoal: String, Codable, CaseIterable {
    case loseWeight, buildMuscle, recomposition, maintain, improveEndurance

    var label: String {
        switch self {
        case .loseWeight: return "Lose weight"
        case .buildMuscle: return "Build muscle"
        case .recomposition: return "Lose fat & build muscle"
        case .maintain: return "Stay healthy"
        case .improveEndurance: return "Improve endurance"
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: return "arrow.down.circle"
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .recomposition: return "arrow.triangle.2.circlepath"
        case .maintain: return "heart.circle"
        case .improveEndurance: return "figure.run"
        }
    }
}

@Model
final class UserProfile: Syncable {
    @Attribute(.unique) var id: UUID
    var email: String?
    var appleUserID: String?
    var displayName: String
    var unitPreference: UnitPreference
    // — Onboarding / body stats (new fields default so pre-existing rows migrate cleanly) —
    var hasCompletedOnboarding: Bool = false
    var sexRaw: String = BiologicalSex.unspecified.rawValue
    var birthYear: Int = 0        // 0 = unset
    var heightCM: Double = 0      // 0 = unset
    var startingWeightKG: Double = 0
    var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    var fitnessGoalRaw: String = FitnessGoal.maintain.rawValue
    var workoutDaysPerWeek: Int = 3
    var dietRestrictions: [String] = []
    var volumeUnitRaw: String = VolumeUnit.milliliters.rawValue
    var distanceUnitRaw: String = DistanceUnit.kilometers.rawValue
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \Goals.user)
    var goals: Goals?

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var fitnessGoal: FitnessGoal {
        get { FitnessGoal(rawValue: fitnessGoalRaw) ?? .maintain }
        set { fitnessGoalRaw = newValue.rawValue }
    }

    var volumeUnit: VolumeUnit {
        get { VolumeUnit(rawValue: volumeUnitRaw) ?? .milliliters }
        set { volumeUnitRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .kilometers }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var age: Int? {
        guard birthYear > 1900 else { return nil }
        return max(Calendar.current.component(.year, from: .now) - birthYear, 0)
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        unitPreference: UnitPreference = .imperial,
        email: String? = nil,
        appleUserID: String? = nil
    ) {
        self.id = id
        self.email = email
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.unitPreference = unitPreference
        self.hasCompletedOnboarding = false
        self.sexRaw = BiologicalSex.unspecified.rawValue
        self.birthYear = 0
        self.heightCM = 0
        self.startingWeightKG = 0
        self.activityLevelRaw = ActivityLevel.moderate.rawValue
        self.fitnessGoalRaw = FitnessGoal.maintain.rawValue
        self.workoutDaysPerWeek = 3
        self.dietRestrictions = []
        self.volumeUnitRaw = VolumeUnit.milliliters.rawValue
        self.distanceUnitRaw = DistanceUnit.kilometers.rawValue
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

@Model
final class Goals: Syncable {
    @Attribute(.unique) var id: UUID
    var calorieTarget: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var waterML: Int
    var stepTarget: Int
    var weightGoalKG: Double?
    /// Nightly sleep target in minutes (new; defaulted for migration).
    var sleepMinutesTarget: Int = 480
    /// Optional "reach my goal weight by" date from onboarding.
    var goalDate: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var user: UserProfile?

    init(
        id: UUID = UUID(),
        calorieTarget: Int = 2000,
        proteinG: Int = 150,
        carbsG: Int = 200,
        fatG: Int = 65,
        waterML: Int = 2000,
        stepTarget: Int = 8000,
        weightGoalKG: Double? = nil,
        sleepMinutesTarget: Int = 480,
        goalDate: Date? = nil
    ) {
        self.id = id
        self.calorieTarget = calorieTarget
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.waterML = waterML
        self.stepTarget = stepTarget
        self.weightGoalKG = weightGoalKG
        self.sleepMinutesTarget = sleepMinutesTarget
        self.goalDate = goalDate
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}
