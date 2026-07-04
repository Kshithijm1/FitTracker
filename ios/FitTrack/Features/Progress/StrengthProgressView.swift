import SwiftUI
import SwiftData
import Charts

/// Per-exercise e1RM/top-set line chart, exercise picker sorted by
/// most-trained (PLAN.md §3).
struct StrengthProgressView: View {
    @Query private var allSets: [SetEntry]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var selectedExerciseID: UUID?

    private var mostTrainedExerciseIDs: [UUID] {
        let counts = Dictionary(grouping: allSets.filter(\.isCompleted)) { $0.workoutItem?.exerciseID }
            .compactMapValues { $0.count }
        return counts.compactMap { key, _ in key }
            .sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
    }

    private var currentExerciseID: UUID? {
        selectedExerciseID ?? mostTrainedExerciseIDs.first
    }

    private var chartPoints: [(date: Date, e1RM: Double)] {
        guard let exerciseID = currentExerciseID else { return [] }
        return allSets
            .filter { $0.isCompleted && !$0.isWarmup && $0.workoutItem?.exerciseID == exerciseID }
            .compactMap { set -> (Date, Double)? in
                guard let date = set.completedAt else { return nil }
                return (date, StrengthMath.estimatedOneRepMax(weightKG: set.weightKG, reps: set.reps))
            }
            .sorted { $0.0 < $1.0 }
    }

    private func exerciseName(_ id: UUID) -> String {
        allExercises.first { $0.id == id }?.name ?? "Exercise"
    }

    var body: some View {
        if mostTrainedExerciseIDs.isEmpty {
            ContentUnavailableView(
                "No sets logged yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Complete a workout to see your strength trend here.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Picker("Exercise", selection: Binding(
                        get: { currentExerciseID ?? mostTrainedExerciseIDs[0] },
                        set: { selectedExerciseID = $0 }
                    )) {
                        ForEach(mostTrainedExerciseIDs, id: \.self) { id in
                            Text(exerciseName(id)).tag(id)
                        }
                    }
                    .pickerStyle(.menu)

                    Card {
                        Chart(chartPoints, id: \.date) { point in
                            LineMark(x: .value("Date", point.date), y: .value("e1RM", point.e1RM))
                                .foregroundStyle(Theme.Color.accent)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Date", point.date), y: .value("e1RM", point.e1RM))
                                .foregroundStyle(Theme.Color.accent)
                        }
                        .frame(height: 220)
                        .chartYAxisLabel("Estimated 1RM (kg)")
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
    }
}
