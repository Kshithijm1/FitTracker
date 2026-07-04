import SwiftUI

/// Water/Steps/Sleep/Move mini-rings. Tap water = instant +1 glass log
/// (single tap); long-press is reserved for a custom-amount sheet in a
/// later phase. Steps/Sleep are read-only here until HealthKit (Phase 3).
struct HabitRingsRow: View {
    let waterML: Int
    let waterGoalML: Int
    let stepsCount: Int
    let stepGoal: Int
    let sleepMinutes: Int
    let onAddWater: () -> Void

    private var waterGlasses: Int { waterML / 250 }
    private var waterGoalGlasses: Int { max(waterGoalML / 250, 1) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HabitTile(
                icon: "drop.fill",
                title: "Water",
                valueText: "\(waterGlasses)/\(waterGoalGlasses)",
                progress: Double(waterML) / Double(max(waterGoalML, 1)),
                action: onAddWater
            )
            HabitTile(
                icon: "figure.walk",
                title: "Steps",
                valueText: stepsCount.formatted(.number.notation(.compactName)),
                progress: Double(stepsCount) / Double(max(stepGoal, 1)),
                action: nil
            )
            HabitTile(
                icon: "moon.fill",
                title: "Sleep",
                valueText: sleepDisplay,
                progress: Double(sleepMinutes) / (8 * 60),
                action: nil
            )
        }
    }

    private var sleepDisplay: String {
        guard sleepMinutes > 0 else { return "--" }
        return "\(sleepMinutes / 60)h\(sleepMinutes % 60)"
    }
}

private struct HabitTile: View {
    let icon: String
    let title: String
    let valueText: String
    let progress: Double
    let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            action?()
        } label: {
            Card {
                VStack(spacing: Theme.Spacing.xs) {
                    ProgressRing(progress: progress, lineWidth: 6, color: Theme.Color.accent)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                    Text(valueText)
                        .font(Theme.Font.numeral(15))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(title)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(title), \(valueText)")
    }
}

#Preview {
    HabitRingsRow(
        waterML: 750, waterGoalML: 2000,
        stepsCount: 6200, stepGoal: 8000,
        sleepMinutes: 432,
        onAddWater: {}
    )
    .padding()
    .background(Theme.Color.background)
}
