import SwiftUI

/// Inline weight/reps/quantity stepper used on set rows and portion rows —
/// never a separate form screen. Long-press either side to accelerate.
///
/// VoiceOver drives this as one adjustable element (swipe up/down to
/// increment/decrement, matching the system `Stepper` convention) rather
/// than exposing the +/- glyphs as separate stops — sighted users still
/// tap them individually since `.accessibilityElement(children:)` only
/// affects the accessibility tree, not touch hit-testing.
struct CompactStepper: View {
    @Binding var value: Double
    let step: Double
    /// What this stepper adjusts (e.g. "weight", "reps") — read by VoiceOver
    /// as the element's label; purely cosmetic for sighted users.
    var label: String? = nil
    var formatter: (Double) -> String = { String(format: "%g", $0) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            stepButton(systemImage: "minus") {
                adjust(by: -step)
            }

            Text(formatter(value))
                .font(Theme.Font.numeral(15))
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(minWidth: 32)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            stepButton(systemImage: "plus") {
                adjust(by: step)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(Theme.Color.surface2, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? "Value")
        .accessibilityValue(formatter(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: step)
            case .decrement: adjust(by: -step)
            @unknown default: break
            }
        }
    }

    private func adjust(by delta: Double) {
        withAnimation(Theme.Motion.quickSpring(reduceMotion: reduceMotion)) {
            value = max(0, value + delta)
        }
        Haptics.light()
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var reps = 8.0
    return CompactStepper(value: $reps, step: 1, label: "reps")
        .padding()
        .background(Theme.Color.background)
}
