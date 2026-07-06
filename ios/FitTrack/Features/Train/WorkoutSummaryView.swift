import SwiftUI

/// One-screen finish summary: volume, PR count, duration (PLAN.md §3).
struct WorkoutSummaryView: View {
    let workout: Workout
    let onDone: () -> Void

    private var totalVolume: Double {
        workout.items.flatMap(\.sets).filter(\.isCompleted).reduce(0) {
            $0 + StrengthMath.volume(weightKG: $1.weightKG, reps: $1.reps)
        }
    }

    private var totalSets: Int {
        workout.items.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var duration: String {
        guard let finishedAt = workout.finishedAt else { return "--" }
        let interval = finishedAt.timeIntervalSince(workout.startedAt)
        let minutes = Int(interval / 60)
        return "\(minutes) min"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Color.accent)

            Text("Workout complete")
                .font(Theme.Font.display28)
                .foregroundStyle(Theme.Color.textPrimary)

            HStack(spacing: Theme.Spacing.xl) {
                SummaryStat(value: totalSets.formatted(), label: "sets")
                SummaryStat(value: totalVolume.formatted(.number.precision(.fractionLength(0))), label: "kg volume")
                SummaryStat(value: duration, label: "duration")
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
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Font.numeral(22))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
