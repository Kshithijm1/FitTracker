import SwiftUI

/// Shows "Continue workout" with live set count when one is in progress,
/// else "Start workout" (PLAN.md §3).
struct ContinueWorkoutCard: View {
    let inProgressWorkout: Workout?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        if let workout = inProgressWorkout {
                            Text("Continue workout")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("\(completedSetCount(workout)) sets in")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        } else {
                            Text("Start workout")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("Repeat last, or pick a routine")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: inProgressWorkout == nil ? "plus.circle.fill" : "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func completedSetCount(_ workout: Workout) -> Int {
        workout.items.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }
}

#Preview {
    ContinueWorkoutCard(inProgressWorkout: nil) {}
        .padding()
        .background(Theme.Color.background)
}
