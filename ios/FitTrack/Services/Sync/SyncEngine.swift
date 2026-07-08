import Foundation
import SwiftData
import Observation

private struct PushBody: Encodable {
    let changes: Changes

    struct Changes: Encodable {
        var goals: [GoalsDTO] = []
        var exercises: [ExerciseDTO] = []
        var routines: [RoutineDTO] = []
        var routineItems: [RoutineItemDTO] = []
        var workouts: [WorkoutDTO] = []
        var workoutItems: [WorkoutItemDTO] = []
        var setEntries: [SetEntryDTO] = []
        var personalRecords: [PersonalRecordDTO] = []
        var weightEntries: [WeightEntryDTO] = []
        var measurementEntries: [MeasurementEntryDTO] = []
        var foodItems: [FoodItemDTO] = []
        var savedMeals: [SavedMealDTO] = []
        var savedMealItems: [SavedMealItemDTO] = []
        var foodLogs: [FoodLogDTO] = []
        var waterEntries: [WaterEntryDTO] = []
        var sleepEntries: [SleepEntryDTO] = []
    }
}

private struct PushResultDTO: Decodable {
    let table: String
    let id: UUID
    let status: String
}

private struct PushResponse: Decodable {
    let results: [PushResultDTO]
}

private struct PullChangesDTO: Decodable {
    var goals: [GoalsDTO]?
    var exercises: [ExerciseDTO]?
    var routines: [RoutineDTO]?
    var routineItems: [RoutineItemDTO]?
    var workouts: [WorkoutDTO]?
    var workoutItems: [WorkoutItemDTO]?
    var setEntries: [SetEntryDTO]?
    var personalRecords: [PersonalRecordDTO]?
    var weightEntries: [WeightEntryDTO]?
    var measurementEntries: [MeasurementEntryDTO]?
    var foodItems: [FoodItemDTO]?
    var savedMeals: [SavedMealDTO]?
    var savedMealItems: [SavedMealItemDTO]?
    var foodLogs: [FoodLogDTO]?
    var waterEntries: [WaterEntryDTO]?
    var sleepEntries: [SleepEntryDTO]?
}

private struct PullResponse: Decodable {
    let changes: PullChangesDTO
    let cursor: Date?
}

/// Pushes locally-dirty SwiftData records, then pulls remote changes since
/// the last cursor, applying the LWW/tombstone rule on both sides (PLAN.md
/// §2/§7). A no-op whenever the user isn't signed in — sync is additive on
/// top of the fully-functional local-only experience, never required.
@MainActor
@Observable
final class SyncEngine {
    private let context: ModelContext
    private static let cursorDefaultsKey = "fittrack.sync.cursor"

    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var lastError: String?

    init(context: ModelContext) {
        self.context = context
    }

    private var cursor: Date? {
        get {
            guard let iso = UserDefaults.standard.string(forKey: Self.cursorDefaultsKey) else { return nil }
            return ISO8601DateFormatter().date(from: iso)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(ISO8601DateFormatter().string(from: newValue), forKey: Self.cursorDefaultsKey)
            }
        }
    }

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await push()
            try await pull()
            lastSyncedAt = .now
            lastError = nil
        } catch {
            // Offline-first: a failed sync is silent to the user (PLAN.md §3
            // offline states are non-blocking) and simply retried next time.
            lastError = "Sync failed — will retry automatically."
        }
    }

    // MARK: - Push

    private func push() async throws {
        var changes = PushBody.Changes()

        changes.goals = try fetchDirty(Goals.self).map(GoalsDTO.init)
        changes.exercises = try fetchDirty(Exercise.self).map(ExerciseDTO.init)
        changes.routines = try fetchDirty(Routine.self).map(RoutineDTO.init)
        changes.routineItems = try fetchDirty(RoutineItem.self).compactMap { item in
            item.routine.map { RoutineItemDTO(item, routineId: $0.id) }
        }
        changes.workouts = try fetchDirty(Workout.self).map(WorkoutDTO.init)
        changes.workoutItems = try fetchDirty(WorkoutItem.self).compactMap { item in
            item.workout.map { WorkoutItemDTO(item, workoutId: $0.id) }
        }
        changes.setEntries = try fetchDirty(SetEntry.self).compactMap { entry in
            entry.workoutItem.map { SetEntryDTO(entry, workoutItemId: $0.id) }
        }
        changes.personalRecords = try fetchDirty(PersonalRecord.self).map(PersonalRecordDTO.init)
        changes.weightEntries = try fetchDirty(WeightEntry.self).map(WeightEntryDTO.init)
        changes.measurementEntries = try fetchDirty(MeasurementEntry.self).map(MeasurementEntryDTO.init)
        changes.foodItems = try fetchDirty(FoodItem.self).map(FoodItemDTO.init)
        changes.savedMeals = try fetchDirty(SavedMeal.self).map(SavedMealDTO.init)
        changes.savedMealItems = try fetchDirty(SavedMealItem.self).compactMap { item in
            item.savedMeal.map { SavedMealItemDTO(item, savedMealId: $0.id) }
        }
        changes.foodLogs = try fetchDirty(FoodLog.self).map(FoodLogDTO.init)
        changes.waterEntries = try fetchDirty(WaterEntry.self).map(WaterEntryDTO.init)
        changes.sleepEntries = try fetchDirty(SleepEntry.self).map(SleepEntryDTO.init)

        let isEmpty = Mirror(reflecting: changes).children.allSatisfy {
            ($0.value as? any Collection)?.isEmpty ?? true
        }
        guard !isEmpty else { return }

        let response: PushResponse = try await APIClient.shared.request(
            "POST", "/v1/sync/push", body: PushBody(changes: changes), authenticated: true
        )

        // Clear the dirty flag for every record the server accepted or
        // superseded — both are terminal outcomes; only a genuine ownership
        // rejection (practically never happens for a solo/few-device user)
        // is left dirty so it's retried rather than silently dropped.
        for result in response.results where result.status != "rejected_not_owner" {
            clearDirtyFlag(table: result.table, id: result.id)
        }
    }

    private func fetchDirty<T: PersistentModel & Syncable>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>(predicate: #Predicate<T> { $0.dirty == true }))
    }

    private func clearDirtyFlag(table: String, id: UUID) {
        func clear<T: PersistentModel & Syncable>(_ type: T.Type) {
            guard let model = try? context.fetch(FetchDescriptor<T>(predicate: #Predicate { $0.id == id })).first else { return }
            model.dirty = false
        }
        switch table {
        case "goals": clear(Goals.self)
        case "exercises": clear(Exercise.self)
        case "routines": clear(Routine.self)
        case "routineItems": clear(RoutineItem.self)
        case "workouts": clear(Workout.self)
        case "workoutItems": clear(WorkoutItem.self)
        case "setEntries": clear(SetEntry.self)
        case "personalRecords": clear(PersonalRecord.self)
        case "weightEntries": clear(WeightEntry.self)
        case "measurementEntries": clear(MeasurementEntry.self)
        case "foodItems": clear(FoodItem.self)
        case "savedMeals": clear(SavedMeal.self)
        case "savedMealItems": clear(SavedMealItem.self)
        case "foodLogs": clear(FoodLog.self)
        case "waterEntries": clear(WaterEntry.self)
        case "sleepEntries": clear(SleepEntry.self)
        default: break
        }
        try? context.save()
    }

    // MARK: - Pull

    private func pull() async throws {
        let path = cursor.map { "/v1/sync/pull?cursor=\(ISO8601DateFormatter().string(from: $0))" } ?? "/v1/sync/pull"
        let response: PullResponse = try await APIClient.shared.request("GET", path, authenticated: true)

        merge(response.changes.goals) { GoalsDTO.newModel(id: $0) }
        merge(response.changes.exercises) { ExerciseDTO.newModel(id: $0) }
        merge(response.changes.routines) { RoutineDTO.newModel(id: $0) }
        merge(response.changes.workouts) { WorkoutDTO.newModel(id: $0) }
        merge(response.changes.personalRecords) { PersonalRecordDTO.newModel(id: $0) }
        merge(response.changes.weightEntries) { WeightEntryDTO.newModel(id: $0) }
        merge(response.changes.measurementEntries) { MeasurementEntryDTO.newModel(id: $0) }
        merge(response.changes.foodItems) { FoodItemDTO.newModel(id: $0) }
        merge(response.changes.savedMeals) { SavedMealDTO.newModel(id: $0) }
        merge(response.changes.foodLogs) { FoodLogDTO.newModel(id: $0) }
        merge(response.changes.waterEntries) { WaterEntryDTO.newModel(id: $0) }
        merge(response.changes.sleepEntries) { SleepEntryDTO.newModel(id: $0) }

        // Children needing their parent relationship set on insert.
        mergeRoutineItems(response.changes.routineItems)
        mergeWorkoutItems(response.changes.workoutItems)
        mergeSetEntries(response.changes.setEntries)
        mergeSavedMealItems(response.changes.savedMealItems)

        try context.save()

        if let newCursor = response.cursor {
            cursor = newCursor
        }
    }

    private func merge<DTO: SyncDTO & SyncDTOApplying, M: PersistentModel & Syncable>(
        _ records: [DTO]?,
        newModel: (UUID) -> M
    ) where DTO.Model == M {
        guard let records else { return }
        for record in records {
            let existing = try? context.fetch(FetchDescriptor<M>(predicate: #Predicate { $0.id == record.id })).first
            let decision = lwwDecision(
                incomingUpdatedAt: record.updatedAt,
                incomingDeletedAt: record.deletedAt,
                existingUpdatedAt: existing?.updatedAt,
                existingDeletedAt: existing?.deletedAt
            )
            switch decision {
            case .insert:
                let model = newModel(record.id)
                record.apply(to: model)
                context.insert(model)
            case .applyUpdate:
                if let existing { record.apply(to: existing) }
            case .skip:
                break
            }
        }
    }

    private func mergeRoutineItems(_ records: [RoutineItemDTO]?) {
        guard let records else { return }
        for record in records {
            guard let routine = try? context.fetch(FetchDescriptor<Routine>(predicate: #Predicate { $0.id == record.routineId })).first else { continue }
            let existing = try? context.fetch(FetchDescriptor<RoutineItem>(predicate: #Predicate { $0.id == record.id })).first
            switch lwwDecision(incomingUpdatedAt: record.updatedAt, incomingDeletedAt: record.deletedAt, existingUpdatedAt: existing?.updatedAt, existingDeletedAt: existing?.deletedAt) {
            case .insert:
                let model = RoutineItemDTO.newModel(id: record.id)
                record.apply(to: model)
                model.routine = routine
                context.insert(model)
            case .applyUpdate:
                if let existing { record.apply(to: existing) }
            case .skip:
                break
            }
        }
    }

    private func mergeWorkoutItems(_ records: [WorkoutItemDTO]?) {
        guard let records else { return }
        for record in records {
            guard let workout = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == record.workoutId })).first else { continue }
            let existing = try? context.fetch(FetchDescriptor<WorkoutItem>(predicate: #Predicate { $0.id == record.id })).first
            switch lwwDecision(incomingUpdatedAt: record.updatedAt, incomingDeletedAt: record.deletedAt, existingUpdatedAt: existing?.updatedAt, existingDeletedAt: existing?.deletedAt) {
            case .insert:
                let model = WorkoutItemDTO.newModel(id: record.id)
                record.apply(to: model)
                model.workout = workout
                context.insert(model)
            case .applyUpdate:
                if let existing { record.apply(to: existing) }
            case .skip:
                break
            }
        }
    }

    private func mergeSetEntries(_ records: [SetEntryDTO]?) {
        guard let records else { return }
        for record in records {
            guard let workoutItem = try? context.fetch(FetchDescriptor<WorkoutItem>(predicate: #Predicate { $0.id == record.workoutItemId })).first else { continue }
            let existing = try? context.fetch(FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == record.id })).first
            switch lwwDecision(incomingUpdatedAt: record.updatedAt, incomingDeletedAt: record.deletedAt, existingUpdatedAt: existing?.updatedAt, existingDeletedAt: existing?.deletedAt) {
            case .insert:
                let model = SetEntryDTO.newModel(id: record.id)
                record.apply(to: model)
                model.workoutItem = workoutItem
                context.insert(model)
            case .applyUpdate:
                if let existing { record.apply(to: existing) }
            case .skip:
                break
            }
        }
    }

    private func mergeSavedMealItems(_ records: [SavedMealItemDTO]?) {
        guard let records else { return }
        for record in records {
            guard let savedMeal = try? context.fetch(FetchDescriptor<SavedMeal>(predicate: #Predicate { $0.id == record.savedMealId })).first else { continue }
            let existing = try? context.fetch(FetchDescriptor<SavedMealItem>(predicate: #Predicate { $0.id == record.id })).first
            switch lwwDecision(incomingUpdatedAt: record.updatedAt, incomingDeletedAt: record.deletedAt, existingUpdatedAt: existing?.updatedAt, existingDeletedAt: existing?.deletedAt) {
            case .insert:
                let model = SavedMealItemDTO.newModel(id: record.id)
                record.apply(to: model)
                model.savedMeal = savedMeal
                context.insert(model)
            case .applyUpdate:
                if let existing { record.apply(to: existing) }
            case .skip:
                break
            }
        }
    }
}

/// Bridges each DTO's `apply(to:)` method (concrete per-type, not part of
/// `SyncDTO`) into the generic `merge(_:newModel:)` helper above.
protocol SyncDTOApplying {
    associatedtype Model
    func apply(to model: Model)
}

extension GoalsDTO: SyncDTOApplying {}
extension ExerciseDTO: SyncDTOApplying {}
extension RoutineDTO: SyncDTOApplying {}
extension WorkoutDTO: SyncDTOApplying {}
extension PersonalRecordDTO: SyncDTOApplying {}
extension WeightEntryDTO: SyncDTOApplying {}
extension MeasurementEntryDTO: SyncDTOApplying {}
extension FoodItemDTO: SyncDTOApplying {}
extension SavedMealDTO: SyncDTOApplying {}
extension FoodLogDTO: SyncDTOApplying {}
extension WaterEntryDTO: SyncDTOApplying {}
extension SleepEntryDTO: SyncDTOApplying {}
