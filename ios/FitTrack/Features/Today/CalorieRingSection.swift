import SwiftUI

/// Calorie ring + macro bars. The budget is `target + burned` — training
/// earns calories back, and the earned portion is called out in its own
/// color (warning/amber, never the accent) so it reads as a bonus, not
/// part of the base plan.
struct CalorieRingSection: View {
    let goals: Goals
    let consumed: MacroSet
    /// kcal earned from finished workouts today (0 hides the bonus chip).
    var burnedKcal: Int = 0

    private var budget: Int { goals.calorieTarget + burnedKcal }

    private var remainingKcal: Int {
        MacroMath.remaining(target: budget, consumed: Int(consumed.kcal))
    }

    private var fraction: Double {
        MacroMath.fractionConsumed(target: budget, consumed: Int(consumed.kcal))
    }

    var body: some View {
        Card {
            VStack(spacing: Theme.Spacing.md) {
                ProgressRing(
                    progress: fraction,
                    lineWidth: 12,
                    label: "kcal left",
                    value: remainingKcal.formatted()
                )
                .frame(width: 160, height: 160)

                if burnedKcal > 0 {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "flame.fill")
                        Text("+\(burnedKcal) earned from training")
                    }
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.warning)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Color.warning.opacity(0.12), in: Capsule())
                    .accessibilityLabel("\(burnedKcal) extra calories earned from training")
                }

                VStack(spacing: Theme.Spacing.sm) {
                    StatBar(
                        label: "Protein",
                        valueText: "\(macroRemaining(goals.proteinG, consumed.protein))g left",
                        progress: consumed.protein / Double(max(goals.proteinG, 1))
                    )
                    StatBar(
                        label: "Carbs",
                        valueText: "\(macroRemaining(goals.carbsG, consumed.carbs))g left",
                        progress: consumed.carbs / Double(max(goals.carbsG, 1))
                    )
                    StatBar(
                        label: "Fat",
                        valueText: "\(macroRemaining(goals.fatG, consumed.fat))g left",
                        progress: consumed.fat / Double(max(goals.fatG, 1))
                    )
                }
            }
        }
    }

    private func macroRemaining(_ targetG: Int, _ consumedG: Double) -> Int {
        MacroMath.remaining(target: targetG, consumed: Int(consumedG))
    }
}

#Preview {
    CalorieRingSection(
        goals: Goals(),
        consumed: MacroSet(kcal: 570, protein: 58, carbs: 60, fat: 27),
        burnedKcal: 230
    )
    .padding()
    .background(Theme.Color.background)
}
