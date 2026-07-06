import SwiftUI

/// Tap = logged instantly at default portion. A quantity stepper then
/// appears inline for a few seconds so the amount can be adjusted without
/// navigating to a separate screen (PLAN.md §3).
struct FoodResultRow: View {
    let item: FoodItem
    let isJustLogged: Bool
    @Binding var pendingQuantity: Double
    let onTap: () -> Void
    let onQuantityChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(item.name)
                            .foregroundStyle(Theme.Color.textPrimary)
                        if let brand = item.brand {
                            Text(brand)
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    Spacer()
                    Text("\(Int(item.per100g.kcal)) kcal/100g")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isJustLogged {
                HStack {
                    Text("Logged")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.accent)
                    Spacer()
                    CompactStepper(value: $pendingQuantity, step: 10, label: "quantity in grams") { "\(Int($0))g" }
                        .onChange(of: pendingQuantity) { _, _ in onQuantityChange() }
                }
                .transition(.opacity)
            }
        }
    }
}
