import Foundation
import Testing
@testable import FitTrack

struct LWWResolverTests {
    @Test func noExistingRecordAlwaysInserts() {
        let decision = lwwDecision(incomingUpdatedAt: .now, incomingDeletedAt: nil, existingUpdatedAt: nil, existingDeletedAt: nil)
        #expect(decision == .insert)
    }

    @Test func newerIncomingUpdateWins() {
        let older = Date()
        let newer = older.addingTimeInterval(60)
        let decision = lwwDecision(incomingUpdatedAt: newer, incomingDeletedAt: nil, existingUpdatedAt: older, existingDeletedAt: nil)
        #expect(decision == .applyUpdate)
    }

    @Test func staleIncomingUpdateIsSkipped() {
        let older = Date()
        let newer = older.addingTimeInterval(60)
        let decision = lwwDecision(incomingUpdatedAt: older, incomingDeletedAt: nil, existingUpdatedAt: newer, existingDeletedAt: nil)
        #expect(decision == .skip)
    }

    @Test func tombstoneWinsAtExactTie() {
        let timestamp = Date()
        let decision = lwwDecision(incomingUpdatedAt: timestamp, incomingDeletedAt: timestamp, existingUpdatedAt: timestamp, existingDeletedAt: nil)
        #expect(decision == .applyUpdate)
    }

    @Test func nonDeletedUpdateDoesNotOverrideExistingTombstoneAtTie() {
        let timestamp = Date()
        let decision = lwwDecision(incomingUpdatedAt: timestamp, incomingDeletedAt: nil, existingUpdatedAt: timestamp, existingDeletedAt: timestamp)
        #expect(decision == .skip)
    }
}
