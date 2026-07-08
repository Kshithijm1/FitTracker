import Foundation

enum LWWDecision {
    case insert
    case applyUpdate
    case skip
}

/// The client-side mirror of the server's conflict rule (PLAN.md §2):
/// per-record last-write-wins on `updatedAt`, tombstones win exact ties.
/// Used when merging pulled remote records into local SwiftData rows that
/// may have been edited locally since the last sync.
func lwwDecision(
    incomingUpdatedAt: Date,
    incomingDeletedAt: Date?,
    existingUpdatedAt: Date?,
    existingDeletedAt: Date?
) -> LWWDecision {
    guard let existingUpdatedAt else { return .insert }

    if incomingUpdatedAt > existingUpdatedAt { return .applyUpdate }

    let isTombstoneTie = incomingUpdatedAt == existingUpdatedAt
        && incomingDeletedAt != nil
        && existingDeletedAt == nil
    if isTombstoneTie { return .applyUpdate }

    return .skip
}
