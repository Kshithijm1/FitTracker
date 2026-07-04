import SwiftUI

/// Thin horizontal fill bar for the macro rows under the calorie ring
/// (protein/carbs/fat). No shadows — separation via `Theme.Color.surface2`
/// as the track.
struct StatBar: View {
    let label: String
    let valueText: String
    /// 0...1
    let progress: Double
    var color: Color = Theme.Color.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text(label)
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
                Text(valueText)
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textPrimary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Color.surface2)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * clamped)
                        .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: clamped)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        StatBar(label: "Protein", valueText: "92g", progress: 0.7)
        StatBar(label: "Carbs", valueText: "140g", progress: 0.45)
        StatBar(label: "Fat", valueText: "38g", progress: 0.3)
    }
    .padding()
    .background(Theme.Color.background)
}
