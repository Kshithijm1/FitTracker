import Foundation
import SwiftData

@Model
final class WaterEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amountML: Int
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(id: UUID = UUID(), date: Date = .now, amountML: Int) {
        self.id = id
        self.date = date
        self.amountML = amountML
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

enum SleepSource: String, Codable {
    case manual, healthkit
}

@Model
final class SleepEntry: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var minutes: Int
    var source: SleepSource
    var updatedAt: Date
    var deletedAt: Date?
    var dirty: Bool

    init(id: UUID = UUID(), date: Date = .now, minutes: Int, source: SleepSource = .manual) {
        self.id = id
        self.date = date
        self.minutes = minutes
        self.source = source
        self.updatedAt = .now
        self.deletedAt = nil
        self.dirty = true
    }
}

enum StepsSource: String, Codable {
    case healthkit, manual
}

/// Device-local only — never synced (PLAN.md §2), so it deliberately does
/// not conform to `Syncable` and has no `dirty`/tombstone fields.
@Model
final class StepsCache {
    @Attribute(.unique) var date: Date
    var steps: Int
    var source: StepsSource

    init(date: Date, steps: Int, source: StepsSource) {
        self.date = date
        self.steps = steps
        self.source = source
    }
}
