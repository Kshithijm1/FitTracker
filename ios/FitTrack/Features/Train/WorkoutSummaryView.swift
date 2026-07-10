import SwiftUI

/// One-screen finish summary: sets, volume, duration, estimated burn —
/// plus a one-line personalized AI insight when available (purely
/// additive; the numbers are deterministic).
struct WorkoutSummaryView: View {
    let workout: Workout
    let onDone: () -> Void

    @Environment(AppContainer.self) private var container
    @State private var insight: String?

    private var completedSets: [SetEntry] {
        workout.items.flatMap(\.sets).filter(\.isCompleted)
    }

    private var totalVolume: Double {
        completedSets.reduce(0) {
            $0 + StrengthMath.volume(weightKG: $1.weightKG, reps: $1.reps)
        }
    }

    private var duration: String {
        guard let finishedAt = workout.finishedAt else { return "--" }
        let minutes = Int(finishedAt.timeIntervalSince(workout.startedAt) / 60)
        return "\(minutes) min"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Color.accent)

            Text(workout.name.isEmpty ? "Workout complete" : "\(workout.name) complete")
                .font(Theme.Font.display28)
                .foregroundStyle(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.lg) {
                SummaryStat(value: completedSets.count.formatted(), label: "sets")
                SummaryStat(value: totalVolume.formatted(.number.precision(.fractionLength(0))), label: "kg volume")
                SummaryStat(value: duration, label: "duration")
                SummaryStat(value: "\(workout.caloriesBurned)", label: "kcal burned")
            }

            if let insight {
                Card {
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.Color.accent)
                        Text(insight)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .transition(.opacity)
            }

            Spacer()

            Button("Done", action: onDone)
                .font(Theme.Font.bodyEmphasized17)
                .foregroundStyle(Theme.Color.onAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.background)
        .task {
            // Soft-fail: no insight, no problem — the screen is complete
            // without it.
            insight = try? await container.ai.quickInsight(
                "The user just finished this workout: \(completedSets.count) sets, "
                + "\(Int(totalVolume))kg volume, \(duration), ~\(workout.caloriesBurned) kcal. "
                + "Give one encouraging, specific observation or tip for next session."
            )
        }
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Font.numeral(20))
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
