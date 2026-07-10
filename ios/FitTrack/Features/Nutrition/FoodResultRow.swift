import SwiftUI

/// Tap = logged instantly at default portion. A quantity + unit editor
/// then appears inline for a few seconds so the amount can be adjusted in
/// any measurement (g, oz, cups, tbsp…) without navigating away.
struct FoodResultRow: View {
    let item: FoodItem
    let isJustLogged: Bool
    @Binding var pendingQuantity: Double
    @Binding var pendingUnit: FoodUnit
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
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Logged")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.accent)
                    Spacer()
                    CompactStepper(
                        value: $pendingQuantity,
                        step: pendingUnit == .grams || pendingUnit == .milliliters ? 10 : 0.25,
                        label: "quantity"
                    ) {
                        pendingUnit == .grams || pendingUnit == .milliliters
                            ? "\(Int($0))" : String(format: "%.2g", $0)
                    }
                    .onChange(of: pendingQuantity) { _, _ in onQuantityChange() }

                    Picker("Unit", selection: $pendingUnit) {
                        ForEach(FoodUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: pendingUnit) { _, newUnit in
                        pendingQuantity = newUnit.defaultQuantity
                        onQuantityChange()
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
