import Foundation

/// Marker for every record that travels through the Phase 2 sync engine.
/// Each conforming `@Model` declares its own stored `id`/`updatedAt`/
/// `deletedAt`/`dirty` (SwiftData models can't inherit stored properties
/// from a protocol), but implementing this documents the contract and lets
/// sync code work generically once Phase 2 lands.
///
/// Conflict rule (PLAN.md §2): per-record last-write-wins on `updatedAt`,
/// tombstones win ties.
protocol Syncable: AnyObject {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var dirty: Bool { get set }
}

extension Syncable {
    /// Call after any local mutation so the push queue picks the record up.
    func markDirty(now: Date = .now) {
        updatedAt = now
        dirty = true
    }

    func markDeleted(now: Date = .now) {
        deletedAt = now
        markDirty(now: now)
    }
}
