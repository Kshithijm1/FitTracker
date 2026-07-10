import Foundation
import SwiftData

/// What a set of this exercise actually measures. Drives which input
/// fields the workout session shows (weight×reps vs. time/speed/incline…).
enum ExerciseTrackingKind: String, Codable, CaseIterable {
    /// Weight + reps (barbell/dumbbell/cable/machine work).
    case weightReps
    /// Reps only, with optional added weight (pull-ups, dips, push-ups).
    case bodyweightReps
    /// Duration only (plank, dead hang, wall sit).
    case timeOnly
    /// Duration + speed + incline (treadmill, stair climber).
    case cardioSpeedIncline
    /// Duration + distance (bike, rowing, swimming).
    case cardioDistance
}

@Model
final class Exercise: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipment: String
    var isCustom: Bool
    var archivedAt: Date?
    /// Raw string (not the enum) so adding kinds later is a data change,
    /// not a schema migration. Default keeps pre-existing rows valid.
    var trackingKindRaw: String = ExerciseTrackingKind.weightReps.rawValue
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var trackingKind: ExerciseTrackingKind {
        get { ExerciseTrackingKind(rawValue: trackingKindRaw) ?? .weightReps }
        set { trackingKindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String],
        equipment: String,
        isCustom: Bool = false,
        trackingKind: ExerciseTrackingKind = .weightReps
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.isCustom = isCustom
        self.archivedAt = nil
        self.trackingKindRaw = trackingKind.rawValue
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = isCustom
    }
}

@Model
final class Routine: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var position: Int
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem]

    init(id: UUID = UUID(), name: String, notes: String = "", position: Int = 0) {
        self.id = id
        self.name = name
        self.notes = notes
        self.position = position
        self.items = []
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

@Model
final class RoutineItem: Syncable {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var position: Int
    var targetSets: Int
    var targetReps: Int
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var routine: Routine?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        position: Int,
        targetSets: Int = 3,
        targetReps: Int = 8
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.position = position
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

@Model
final class Workout: Syncable {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var routineID: UUID?
    var notes: String
    /// Display name ("Push Day"); copied from the routine at start time so
    /// history reads well even if the routine is later renamed/deleted.
    var name: String = ""
    /// Estimated energy burned, filled in at finish (MET-based, see
    /// `CalorieBurnMath`). 0 = not yet estimated.
    var caloriesBurned: Int = 0
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutItem.workout)
    var items: [WorkoutItem]

    /// A workout is "in progress" (shown on Today as "Continue workout")
    /// exactly when `finishedAt` is nil.
    var isInProgress: Bool { finishedAt == nil }

    init(id: UUID = UUID(), startedAt: Date = .now, routineID: UUID? = nil, notes: String = "", name: String = "") {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = nil
        self.routineID = routineID
        self.notes = notes
        self.name = name
        self.caloriesBurned = 0
        self.items = []
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

@Model
final class WorkoutItem: Syncable {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var position: Int
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutItem)
    var sets: [SetEntry]

    init(id: UUID = UUID(), exerciseID: UUID, position: Int) {
        self.id = id
        self.exerciseID = exerciseID
        self.position = position
        self.sets = []
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

/// How a set was performed. Warmups are excluded from PRs; drop/failure
/// sets get distinct icons in the session UI instead of a plain number.
enum SetType: String, Codable, CaseIterable {
    case warmup, normal, drop, failure

    /// Short badge label shown in place of the set number (normal sets
    /// show their running number instead).
    var badge: String? {
        switch self {
        case .warmup: return "W"
        case .normal: return nil
        case .drop: return "D"
        case .failure: return "F"
        }
    }
}

@Model
final class SetEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var index: Int
    var weightKG: Double
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var completedAt: Date?
    /// Raw string for migration safety; see `setType`.
    var setTypeRaw: String = SetType.normal.rawValue
    // Cardio/duration metrics — used according to the exercise's
    // `trackingKind`; zero when not applicable.
    var durationSec: Int = 0
    var distanceM: Double = 0
    var speedKPH: Double = 0
    var inclinePct: Double = 0
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var workoutItem: WorkoutItem?

    /// True once the user has tapped the checkmark for this row.
    var isCompleted: Bool { completedAt != nil }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? (isWarmup ? .warmup : .normal) }
        set {
            setTypeRaw = newValue.rawValue
            // Kept in lockstep so PR detection and the sync payload (which
            // predate `setType`) stay correct.
            isWarmup = newValue == .warmup
        }
    }

    init(
        id: UUID = UUID(),
        index: Int,
        weightKG: Double,
        reps: Int,
        rpe: Double? = nil,
        setType: SetType = .normal
    ) {
        self.id = id
        self.index = index
        self.weightKG = weightKG
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = setType == .warmup
        self.completedAt = nil
        self.setTypeRaw = setType.rawValue
        self.durationSec = 0
        self.distanceM = 0
        self.speedKPH = 0
        self.inclinePct = 0
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

enum PersonalRecordKind: String, Codable {
    case weight, reps, volume, e1RM
}

@Model
final class PersonalRecord: Syncable {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var kind: PersonalRecordKind
    var value: Double
    var setEntryID: UUID
    var achievedAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        kind: PersonalRecordKind,
        value: Double,
        setEntryID: UUID,
        achievedAt: Date = .now
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.kind = kind
        self.value = value
        self.setEntryID = setEntryID
        self.achievedAt = achievedAt
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}
