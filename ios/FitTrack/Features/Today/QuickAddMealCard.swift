import SwiftUI

/// Context-aware "+ Log lunch/dinner/…" card. Tapping anywhere opens the
/// log sheet straight into recents (PLAN.md §3).
struct QuickAddMealCard: View {
    let slot: MealSlot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("+ Log \(slot.rawValue)")
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("Usual · Search · Barcode")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickAddMealCard(slot: .lunch) {}
        .padding()
        .background(Theme.Color.background)
}
