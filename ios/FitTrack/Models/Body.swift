import Foundation
import SwiftData

@Model
final class WeightEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKG: Double
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(id: UUID = UUID(), date: Date = .now, weightKG: Double) {
        self.id = id
        self.date = date
        self.weightKG = weightKG
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

enum MeasurementSite: String, Codable, CaseIterable {
    case waist, chest, arm, thigh, hip, neck, calf
}

@Model
final class MeasurementEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var site: MeasurementSite
    var valueCM: Double
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(id: UUID = UUID(), date: Date = .now, site: MeasurementSite, valueCM: Double) {
        self.id = id
        self.date = date
        self.site = site
        self.valueCM = valueCM
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

/// Progress photos are local-only in v1 — deliberately NOT `Syncable`.
/// Stored under iOS file protection `.complete` (see PLAN.md §5); the sync
/// engine must never enumerate this table.
@Model
final class ProgressPhoto {
    @Attribute(.unique) var id: UUID
    var date: Date
    var localFileURL: URL

    init(id: UUID = UUID(), date: Date = .now, localFileURL: URL) {
        self.id = id
        self.date = date
        self.localFileURL = localFileURL
    }
}
