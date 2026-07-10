import Foundation
import SwiftData
import Testing
@testable import FitTrack

@MainActor
struct PRDetectorServiceTests {
    
    // FIXED: Return a tuple containing the container so it stays alive in memory during the test execution
    private func createTestStack() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([SetEntry.self, PersonalRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, container.mainContext)
    }

    @Test func firstSetForExerciseIsAPRInEveryCategory() throws {
        let (_container, context) = try createTestStack() // Retains the container instance!
        let detector = PRDetectorService()
        let exerciseID = UUID()
        
        let entry = SetEntry(
            id: UUID(),
            index: 0,
            weightKG: 100.0,
            reps: 8,
            rpe: nil,
            setType: .normal
        )

        let achieved = detector.evaluate(set: entry, exerciseID: exerciseID, priorRecords: [], context: context)

        #expect(Set(achieved) == Set<PersonalRecordKind>([.weight, .reps, .volume, .e1RM]))
    }

    @Test func lighterSetAfterAPRIsNotAPR() throws {
        let (_container, context) = try createTestStack() // Retains the container instance!
        let detector = PRDetectorService()
        let exerciseID = UUID()
        let setEntryID = UUID()

        let historicalPRs = [
            PersonalRecord(exerciseID: exerciseID, kind: .weight, value: 100.0, setEntryID: setEntryID),
            PersonalRecord(exerciseID: exerciseID, kind: .reps, value: 8.0, setEntryID: setEntryID),
            PersonalRecord(exerciseID: exerciseID, kind: .volume, value: 800.0, setEntryID: setEntryID),
            PersonalRecord(exerciseID: exerciseID, kind: .e1RM, value: 126.0, setEntryID: setEntryID)
        ]
        
        let subMaximalEntry = SetEntry(id: UUID(), index: 1, weightKG: 90.0, reps: 8, rpe: nil, setType: .normal)
        
        let secondAchieved = detector.evaluate(
            set: subMaximalEntry,
            exerciseID: exerciseID,
            priorRecords: historicalPRs,
            context: context
        )

        #expect(secondAchieved.isEmpty)
    }

    @Test func warmupSetsNeverCountAsPRs() throws {
        let (_container, context) = try createTestStack() // Retains the container instance!
        let detector = PRDetectorService()
        let exerciseID = UUID()
        
        let entry = SetEntry(id: UUID(), index: 0, weightKG: 999.0, reps: 20, rpe: nil, setType: .warmup)

        let achieved = detector.evaluate(set: entry, exerciseID: exerciseID, priorRecords: [], context: context)

        #expect(achieved.isEmpty)
    }
}
