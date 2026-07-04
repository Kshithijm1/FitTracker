import Foundation
import SwiftData
import Testing
@testable import FitTrack

@MainActor
struct PRDetectorServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([PersonalRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    @Test func firstSetForExerciseIsAPRInEveryCategory() throws {
        let context = try makeContext()
        let detector = PRDetectorService()
        let exerciseID = UUID()
        let entry = SetEntry(index: 0, weightKG: 100, reps: 8)

        let achieved = try detector.evaluate(set: entry, exerciseID: exerciseID, context: context)

        #expect(Set(achieved) == Set([.weight, .reps, .volume, .e1RM]))
    }

    @Test func lighterSetAfterAPRIsNotAPR() throws {
        let context = try makeContext()
        let detector = PRDetectorService()
        let exerciseID = UUID()

        _ = try detector.evaluate(
            set: SetEntry(index: 0, weightKG: 100, reps: 8),
            exerciseID: exerciseID,
            context: context
        )
        let secondAchieved = try detector.evaluate(
            set: SetEntry(index: 0, weightKG: 90, reps: 8),
            exerciseID: exerciseID,
            context: context
        )

        #expect(secondAchieved.isEmpty)
    }

    @Test func warmupSetsNeverCountAsPRs() throws {
        let context = try makeContext()
        let detector = PRDetectorService()
        let exerciseID = UUID()
        let entry = SetEntry(index: 0, weightKG: 999, reps: 20, isWarmup: true)

        let achieved = try detector.evaluate(set: entry, exerciseID: exerciseID, context: context)

        #expect(achieved.isEmpty)
    }
}
