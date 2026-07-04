import Foundation
import SwiftData

enum UnitPreference: String, Codable {
    case imperial // lb
    case metric   // kg
}

@Model
final class UserProfile: Syncable {
    @Attribute(.unique) var id: UUID
    var email: String?
    var appleUserID: String?
    var displayName: String
    var unitPreference: UnitPreference
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    @Relationship(deleteRule: .cascade, inverse: \Goals.user)
    var goals: Goals?

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
        weightGoalKG: Double? = nil
    ) {
        self.id = id
        self.calorieTarget = calorieTarget
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.waterML = waterML
        self.stepTarget = stepTarget
        self.weightGoalKG = weightGoalKG
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}
