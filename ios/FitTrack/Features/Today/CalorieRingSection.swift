import SwiftUI

/// Calorie ring + the three macro `StatBar`s underneath, all showing
/// "remaining" (never "over budget" as a negative number) per PLAN.md §3.
struct CalorieRingSection: View {
    let goals: Goals
    let consumed: MacroSet

    private var remainingKcal: Int {
        MacroMath.remaining(target: goals.calorieTarget, consumed: Int(consumed.kcal))
    }

    private var fraction: Double {
        MacroMath.fractionConsumed(target: goals.calorieTarget, consumed: Int(consumed.kcal))
    }

    var body: some View {
        Card {
            VStack(spacing: Theme.Spacing.md) {
                ProgressRing(
                    progress: fraction,
                    lineWidth: 12,
                    value: remainingKcal.formatted(),
                    label: "kcal left"
                )
                .frame(width: 160, height: 160)

                VStack(spacing: Theme.Spacing.sm) {
                    StatBar(
                        label: "Protein",
                        valueText: "\(macroRemaining(goals.proteinG, consumed.protein))g",
                        progress: consumed.protein / Double(max(goals.proteinG, 1))
                    )
                    StatBar(
                        label: "Carbs",
                        valueText: "\(macroRemaining(goals.carbsG, consumed.carbs))g",
                        progress: consumed.carbs / Double(max(goals.carbsG, 1))
                    )
                    StatBar(
                        label: "Fat",
                        valueText: "\(macroRemaining(goals.fatG, consumed.fat))g",
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
        consumed: MacroSet(kcal: 570, protein: 58, carbs: 60, fat: 27)
    )
    .padding()
    .background(Theme.Color.background)
}
