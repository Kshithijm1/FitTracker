import Foundation
import SwiftData

@Model
final class Exercise: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipment: String
    var isCustom: Bool
    var archivedAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String],
        equipment: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.isCustom = isCustom
        self.archivedAt = nil
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
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutItem.workout)
    var items: [WorkoutItem]

    /// A workout is "in progress" (shown on Today as "Continue workout")
    /// exactly when `finishedAt` is nil.
    var isInProgress: Bool { finishedAt == nil }

    init(id: UUID = UUID(), startedAt: Date = .now, routineID: UUID? = nil, notes: String = "") {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = nil
        self.routineID = routineID
        self.notes = notes
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

@Model
final class SetEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var index: Int
    var weightKG: Double
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var completedAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var workoutItem: WorkoutItem?

    /// True once the user has tapped the checkmark for this row.
    var isCompleted: Bool { completedAt != nil }

    init(
        id: UUID = UUID(),
        index: Int,
        weightKG: Double,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.index = index
        self.weightKG = weightKG
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = nil
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
