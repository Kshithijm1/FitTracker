import SwiftUI

/// The calorie/habit ring used on Today. Track in `Theme.Color.ringTrack`,
/// fill in `Theme.Color.accent` (or an override color for secondary rings),
/// numeral centered using the rounded numeral font.
struct ProgressRing: View {
    /// 0...1, clamped internally — callers pass raw fractions freely.
    let progress: Double
    var lineWidth: CGFloat = 10
    var color: Color = Theme.Color.accent
    var label: String? = nil
    var value: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: clamped)

            if let value {
                VStack(spacing: 2) {
                    Text(value)
                        .font(Theme.Font.numeral(28))
                        .foregroundStyle(Theme.Color.textPrimary)
                    if let label {
                        Text(label)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

#Preview {
    ProgressRing(progress: 0.62, label: "kcal left", value: "1,430")
        .frame(width: 160, height: 160)
        .padding()
        .background(Theme.Color.background)
}
