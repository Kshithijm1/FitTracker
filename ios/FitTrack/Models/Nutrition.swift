import Foundation
import SwiftData

enum FoodSource: String, Codable {
    case usda, off, custom, estimate
}

struct MacroSet: Codable, Hashable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct FoodServing: Codable, Hashable {
    var label: String
    var grams: Double
}

@Model
final class FoodItem: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String?
    var source: FoodSource
    var barcode: String?
    var per100g: MacroSet
    var servings: [FoodServing]
    var lastUsedAt: Date?
    var useCount: Int
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        source: FoodSource,
        barcode: String? = nil,
        per100g: MacroSet,
        servings: [FoodServing] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source
        self.barcode = barcode
        self.per100g = per100g
        self.servings = servings
        self.lastUsedAt = nil
        self.useCount = 0
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }

    /// Bumped whenever this item is logged, so recents/frequents can rank by it.
    func recordUse(at date: Date = .now) {
        lastUsedAt = date
        useCount += 1
        markDirty(now: date)
    }
}

@Model
final class SavedMeal: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \SavedMealItem.savedMeal)
    var items: [SavedMealItem]

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.items = []
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

@Model
final class SavedMealItem: Syncable {
    @Attribute(.unique) var id: UUID
    var foodItemID: UUID
    var quantityG: Double
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    var savedMeal: SavedMeal?

    init(id: UUID = UUID(), foodItemID: UUID, quantityG: Double) {
        self.id = id
        self.foodItemID = foodItemID
        self.quantityG = quantityG
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

enum MealSlot: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack

    /// Default slot suggested by time of day, for the Today quick-add card.
    static func current(at date: Date = .now) -> MealSlot {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}

@Model
final class FoodLog: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var slot: MealSlot
    var foodItemID: UUID
    var quantityG: Double
    /// Snapshot at log time so later edits to the source `FoodItem` never
    /// rewrite history (PLAN.md §2).
    var macroSnapshot: MacroSet
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(
        id: UUID = UUID(),
        date: Date = .now,
        slot: MealSlot,
        foodItemID: UUID,
        quantityG: Double,
        macroSnapshot: MacroSet
    ) {
        self.id = id
        self.date = date
        self.slot = slot
        self.foodItemID = foodItemID
        self.quantityG = quantityG
        self.macroSnapshot = macroSnapshot
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}
