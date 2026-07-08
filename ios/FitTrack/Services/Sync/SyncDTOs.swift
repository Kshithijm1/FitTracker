import Foundation

/// One wire-format struct per syncable table (PLAN.md §2 SYNCABLE_TABLES on
/// the backend). Field names here are exactly what `backend/src/sync/schemas.ts`
/// expects — deliberately NOT the same casing as the Swift model properties
/// (e.g. `weightKg` not `weightKG`), so each DTO's job is that one
/// translation. Kept as plain structs (not extensions on the `@Model`
/// types) so the wire format can evolve independently of local storage.

struct MacroSetDTO: Codable {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    init(_ macro: MacroSet) {
        kcal = macro.kcal; protein = macro.protein; carbs = macro.carbs; fat = macro.fat
    }
    var model: MacroSet { MacroSet(kcal: kcal, protein: protein, carbs: carbs, fat: fat) }
}

struct FoodServingDTO: Codable {
    let label: String
    let grams: Double

    init(_ serving: FoodServing) { label = serving.label; grams = serving.grams }
    var model: FoodServing { FoodServing(label: label, grams: grams) }
}

protocol SyncDTO: Codable {
    var id: UUID { get }
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

struct GoalsDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let calorieTarget: Int, proteinG: Int, carbsG: Int, fatG: Int
    let waterMl: Int, stepTarget: Int, weightGoalKg: Double?

    init(_ m: Goals) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        calorieTarget = m.calorieTarget; proteinG = m.proteinG; carbsG = m.carbsG; fatG = m.fatG
        waterMl = m.waterML; stepTarget = m.stepTarget; weightGoalKg = m.weightGoalKG
    }
    func apply(to m: Goals) {
        m.calorieTarget = calorieTarget; m.proteinG = proteinG; m.carbsG = carbsG; m.fatG = fatG
        m.waterML = waterMl; m.stepTarget = stepTarget; m.weightGoalKG = weightGoalKg
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> Goals { Goals(id: id) }
}

struct ExerciseDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let name: String, muscleGroups: [String], equipment: String, isCustom: Bool, archivedAt: Date?

    init(_ m: Exercise) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        name = m.name; muscleGroups = m.muscleGroups; equipment = m.equipment
        isCustom = m.isCustom; archivedAt = m.archivedAt
    }
    func apply(to m: Exercise) {
        m.name = name; m.muscleGroups = muscleGroups; m.equipment = equipment
        m.isCustom = isCustom; m.archivedAt = archivedAt
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> Exercise { Exercise(id: id, name: "", muscleGroups: [], equipment: "") }
}

struct RoutineDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let name: String, notes: String, position: Int

    init(_ m: Routine) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        name = m.name; notes = m.notes; position = m.position
    }
    func apply(to m: Routine) {
        m.name = name; m.notes = notes; m.position = position
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> Routine { Routine(id: id, name: "") }
}

struct RoutineItemDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let routineId: UUID, exerciseId: UUID, position: Int, targetSets: Int, targetReps: Int

    init(_ m: RoutineItem, routineId: UUID) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        self.routineId = routineId; exerciseId = m.exerciseID
        position = m.position; targetSets = m.targetSets; targetReps = m.targetReps
    }
    func apply(to m: RoutineItem) {
        m.exerciseID = exerciseId; m.position = position; m.targetSets = targetSets; m.targetReps = targetReps
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> RoutineItem { RoutineItem(id: id, exerciseID: UUID(), position: 0) }
}

struct WorkoutDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let startedAt: Date, finishedAt: Date?, routineId: UUID?, notes: String

    init(_ m: Workout) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        startedAt = m.startedAt; finishedAt = m.finishedAt; routineId = m.routineID; notes = m.notes
    }
    func apply(to m: Workout) {
        m.startedAt = startedAt; m.finishedAt = finishedAt; m.routineID = routineId; m.notes = notes
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> Workout { Workout(id: id) }
}

struct WorkoutItemDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let workoutId: UUID, exerciseId: UUID, position: Int

    init(_ m: WorkoutItem, workoutId: UUID) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        self.workoutId = workoutId; exerciseId = m.exerciseID; position = m.position
    }
    func apply(to m: WorkoutItem) {
        m.exerciseID = exerciseId; m.position = position
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> WorkoutItem { WorkoutItem(id: id, exerciseID: UUID(), position: 0) }
}

struct SetEntryDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let workoutItemId: UUID, index: Int, weightKg: Double, reps: Int
    let rpe: Double?, isWarmup: Bool, completedAt: Date?

    init(_ m: SetEntry, workoutItemId: UUID) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        self.workoutItemId = workoutItemId; index = m.index; weightKg = m.weightKG; reps = m.reps
        rpe = m.rpe; isWarmup = m.isWarmup; completedAt = m.completedAt
    }
    func apply(to m: SetEntry) {
        m.index = index; m.weightKG = weightKg; m.reps = reps
        m.rpe = rpe; m.isWarmup = isWarmup; m.completedAt = completedAt
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> SetEntry { SetEntry(id: id, index: 0, weightKG: 0, reps: 0) }
}

struct PersonalRecordDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let exerciseId: UUID, kind: PersonalRecordKind, value: Double, setEntryId: UUID, achievedAt: Date

    init(_ m: PersonalRecord) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        exerciseId = m.exerciseID; kind = m.kind; value = m.value; setEntryId = m.setEntryID; achievedAt = m.achievedAt
    }
    func apply(to m: PersonalRecord) {
        m.exerciseID = exerciseId; m.kind = kind; m.value = value; m.setEntryID = setEntryId; m.achievedAt = achievedAt
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> PersonalRecord {
        PersonalRecord(id: id, exerciseID: UUID(), kind: .weight, value: 0, setEntryID: UUID())
    }
}

struct WeightEntryDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let date: Date, weightKg: Double

    init(_ m: WeightEntry) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt; date = m.date; weightKg = m.weightKG
    }
    func apply(to m: WeightEntry) {
        m.date = date; m.weightKG = weightKg
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> WeightEntry { WeightEntry(id: id, weightKG: 0) }
}

struct MeasurementEntryDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let date: Date, site: MeasurementSite, valueCm: Double

    init(_ m: MeasurementEntry) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt; date = m.date; site = m.site; valueCm = m.valueCM
    }
    func apply(to m: MeasurementEntry) {
        m.date = date; m.site = site; m.valueCM = valueCm
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> MeasurementEntry { MeasurementEntry(id: id, site: .waist, valueCM: 0) }
}

struct FoodItemDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let name: String, brand: String?, source: FoodSource, barcode: String?
    let per100g: MacroSetDTO, servings: [FoodServingDTO], lastUsedAt: Date?, useCount: Int

    init(_ m: FoodItem) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        name = m.name; brand = m.brand; source = m.source; barcode = m.barcode
        per100g = MacroSetDTO(m.per100g); servings = m.servings.map(FoodServingDTO.init)
        lastUsedAt = m.lastUsedAt; useCount = m.useCount
    }
    func apply(to m: FoodItem) {
        m.name = name; m.brand = brand; m.source = source; m.barcode = barcode
        m.per100g = per100g.model; m.servings = servings.map(\.model)
        m.lastUsedAt = lastUsedAt; m.useCount = useCount
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> FoodItem {
        FoodItem(id: id, name: "", source: .custom, per100g: MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0))
    }
}

struct SavedMealDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let name: String

    init(_ m: SavedMeal) { id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt; name = m.name }
    func apply(to m: SavedMeal) {
        m.name = name
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> SavedMeal { SavedMeal(id: id, name: "") }
}

struct SavedMealItemDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let savedMealId: UUID, foodItemId: UUID, quantityG: Double

    init(_ m: SavedMealItem, savedMealId: UUID) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        self.savedMealId = savedMealId; foodItemId = m.foodItemID; quantityG = m.quantityG
    }
    func apply(to m: SavedMealItem) {
        m.foodItemID = foodItemId; m.quantityG = quantityG
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> SavedMealItem { SavedMealItem(id: id, foodItemID: UUID(), quantityG: 0) }
}

struct FoodLogDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let date: Date, slot: MealSlot, foodItemId: UUID, quantityG: Double, macroSnapshot: MacroSetDTO

    init(_ m: FoodLog) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt
        date = m.date; slot = m.slot; foodItemId = m.foodItemID; quantityG = m.quantityG
        macroSnapshot = MacroSetDTO(m.macroSnapshot)
    }
    func apply(to m: FoodLog) {
        m.date = date; m.slot = slot; m.foodItemID = foodItemId; m.quantityG = quantityG
        m.macroSnapshot = macroSnapshot.model
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> FoodLog {
        FoodLog(id: id, slot: .snack, foodItemID: UUID(), quantityG: 0, macroSnapshot: MacroSet(kcal: 0, protein: 0, carbs: 0, fat: 0))
    }
}

struct WaterEntryDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let date: Date, amountMl: Int

    init(_ m: WaterEntry) { id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt; date = m.date; amountMl = m.amountML }
    func apply(to m: WaterEntry) {
        m.date = date; m.amountML = amountMl
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> WaterEntry { WaterEntry(id: id, amountML: 0) }
}

struct SleepEntryDTO: SyncDTO {
    let id: UUID, updatedAt: Date, deletedAt: Date?
    let date: Date, minutes: Int, source: SleepSource

    init(_ m: SleepEntry) {
        id = m.id; updatedAt = m.updatedAt; deletedAt = m.deletedAt; date = m.date; minutes = m.minutes; source = m.source
    }
    func apply(to m: SleepEntry) {
        m.date = date; m.minutes = minutes; m.source = source
        m.updatedAt = updatedAt; m.deletedAt = deletedAt; m.dirty = false
    }
    static func newModel(id: UUID) -> SleepEntry { SleepEntry(id: id, minutes: 0) }
}
