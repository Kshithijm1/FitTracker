import SwiftUI
import SwiftData
import Charts

/// Search any exercise → full progress since day one: e1RM trend chart,
/// bests, session count, and change-over-time insights.
struct ExerciseProgressView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<SetEntry> { $0.completedAt != nil && !$0.isWarmup })
    private var allSets: [SetEntry]

    @State private var searchText = ""
    @State private var selected: Exercise?

    /// Exercises with at least one completed set, most-trained first.
    private var trainedExercises: [Exercise] {
        let counts = Dictionary(grouping: allSets) { $0.workoutItem?.exerciseID }
            .compactMapValues(\.count)
        return exercises
            .filter { counts[$0.id] != nil }
            .sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
    }

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return trainedExercises }
        return trainedExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if let selected {
                ExerciseProgressDetail(exercise: selected, onBack: { self.selected = nil })
            } else {
                list
            }
        }
        .navigationTitle("Exercise Progress")
        .background(Theme.Color.background)
    }

    private var list: some View {
        Group {
            if trainedExercises.isEmpty {
                ContentUnavailableView(
                    "Nothing tracked yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Log sets in a workout, then search any exercise here to see your progress since day one.")
                )
            } else {
                List(filtered) { exercise in
                    Button {
                        selected = exercise
                    } label: {
                        HStack {
                            Text(exercise.name)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search an exercise (e.g. Bench Press)")
            }
        }
    }
}

private struct ExerciseProgressDetail: View {
    let exercise: Exercise
    let onBack: () -> Void

    @Query private var sets: [SetEntry]
    @Query private var profiles: [UserProfile]

    init(exercise: Exercise, onBack: @escaping () -> Void) {
        self.exercise = exercise
        self.onBack = onBack
        let id = exercise.id
        _sets = Query(
            filter: #Predicate<SetEntry> {
                $0.workoutItem?.exerciseID == id && $0.completedAt != nil && !$0.isWarmup
            },
            sort: [SortDescriptor(\.completedAt)]
        )
    }

    private var unit: UnitPreference { profiles.first?.unitPreference ?? .imperial }

    /// Best e1RM per day — the chart's series.
    private var dailyBest: [(date: Date, e1RM: Double)] {
        var byDay: [Date: Double] = [:]
        for set in sets {
            guard let completedAt = set.completedAt else { continue }
            let day = Calendar.current.startOfDay(for: completedAt)
            let e1RM = StrengthMath.estimatedOneRepMax(weightKG: set.weightKG, reps: set.reps)
            byDay[day] = max(byDay[day] ?? 0, e1RM)
        }
        return byDay.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var sessionCount: Int { dailyBest.count }
    private var bestWeightKG: Double { sets.map(\.weightKG).max() ?? 0 }
    private var bestE1RM: Double { dailyBest.map(\.e1RM).max() ?? 0 }

    private var changeText: String? {
        guard let first = dailyBest.first, let last = dailyBest.last, first.date != last.date, first.e1RM > 0 else { return nil }
        let pct = (last.e1RM - first.e1RM) / first.e1RM * 100
        let weeks = max(Calendar.current.dateComponents([.weekOfYear], from: first.date, to: last.date).weekOfYear ?? 1, 1)
        return String(
            format: "Your estimated 1RM is %@%.0f%% since %@ — over %d weeks of training.",
            pct >= 0 ? "up " : "down ", abs(pct),
            first.date.formatted(date: .abbreviated, time: .omitted), weeks
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Button(action: onBack) {
                    Label("All exercises", systemImage: "chevron.left")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)

                Text(exercise.name)
                    .font(Theme.Font.display28)
                    .foregroundStyle(Theme.Color.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    statCard(Units.formatWeight(bestWeightKG, unit: unit, decimals: 0), "best weight")
                    statCard(Units.formatWeight(bestE1RM, unit: unit, decimals: 0), "best e1RM")
                    statCard("\(sessionCount)", "sessions")
                }

                if dailyBest.count >= 2 {
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Estimated 1RM over time")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                            Chart(dailyBest, id: \.date) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("e1RM", Units.displayWeight(point.e1RM, unit: unit))
                                )
                                .foregroundStyle(Theme.Color.accent)
                                .interpolationMethod(.monotone)
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("e1RM", Units.displayWeight(point.e1RM, unit: unit))
                                )
                                .foregroundStyle(Theme.Color.accent)
                            }
                            .frame(height: 220)
                            .chartYAxisLabel("e1RM (\(Units.weightLabel(unit)))")
                        }
                    }
                }

                if let changeText {
                    Card {
                        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Theme.Color.accent)
                            Text(changeText)
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Full log, newest first — the "with dates" record the user asked for.
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Every session")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                        ForEach(dailyBest.reversed(), id: \.date) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                Spacer()
                                Text("e1RM \(Units.formatWeight(entry.e1RM, unit: unit, decimals: 0))")
                                    .font(Theme.Font.numeral(15))
                                    .foregroundStyle(Theme.Color.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        Card {
            VStack(spacing: 2) {
                Text(value)
                    .font(Theme.Font.numeral(18))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
