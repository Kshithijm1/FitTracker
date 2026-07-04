import Foundation
import SwiftData

/// Recomputes personal records whenever a set is saved. Runs against the
/// prior history for the same exercise (excluding warmups and the row
/// being saved), so it can be called eagerly on every checkmark tap
/// without needing to know in advance whether a PR occurred.
struct PRDetectorService {
    /// Returns the kinds of PR the given set achieves, if any, and inserts
    /// a `PersonalRecord` row for each. Callers show `PRBadge` for a
    /// non-empty result.
    @discardableResult
    func evaluate(
        set entry: SetEntry,
        exerciseID: UUID,
        context: ModelContext
    ) throws -> [PersonalRecordKind] {
        guard !entry.isWarmup else { return [] }

        let priorRecords = try context.fetch(
            FetchDescriptor<PersonalRecord>(
                predicate: #Predicate { $0.exerciseID == exerciseID }
            )
        )

        var achieved: [PersonalRecordKind] = []
        let candidates: [(PersonalRecordKind, Double)] = [
            (.weight, entry.weightKG),
            (.reps, Double(entry.reps)),
            (.volume, StrengthMath.volume(weightKG: entry.weightKG, reps: entry.reps)),
            (.e1RM, StrengthMath.estimatedOneRepMax(weightKG: entry.weightKG, reps: entry.reps)),
        ]

        for (kind, value) in candidates {
            let best = priorRecords.filter { $0.kind == kind }.map(\.value).max() ?? 0
            guard value > best else { continue }
            achieved.append(kind)
            context.insert(PersonalRecord(
                exerciseID: exerciseID,
                kind: kind,
                value: value,
                setEntryID: entry.id
            ))
        }
        return achieved
    }
}
