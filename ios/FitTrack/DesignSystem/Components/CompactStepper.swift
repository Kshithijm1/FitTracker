import SwiftUI

/// Inline weight/reps/quantity stepper used on set rows and portion rows —
/// never a separate form screen. Long-press either side to accelerate.
struct CompactStepper: View {
    @Binding var value: Double
    let step: Double
    var formatter: (Double) -> String = { String(format: "%g", $0) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            stepButton(systemImage: "minus") {
                adjust(by: -step)
            }

            Text(formatter(value))
                .font(Theme.Font.numeral(17))
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(minWidth: 44)
                .contentTransition(.numericText())

            stepButton(systemImage: "plus") {
                adjust(by: step)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(Theme.Color.surface2, in: Capsule())
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var reps = 8.0
    return CompactStepper(value: $reps, step: 1)
        .padding()
        .background(Theme.Color.background)
}
