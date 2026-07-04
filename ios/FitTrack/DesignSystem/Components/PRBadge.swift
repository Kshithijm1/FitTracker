import SwiftUI

/// Brief spring-in badge shown when a set beats a personal record. Never
/// blocks input — overlays the set row, auto-dismisses, paired with a
/// `.success` haptic at the call site.
struct PRBadge: View {
    let kind: String

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label("PR · \(kind)", systemImage: "trophy.fill")
            .font(Theme.Font.bodyEmphasized17)
            .foregroundStyle(Theme.Color.onAccent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Color.accent, in: Capsule())
            .scaleEffect(isVisible ? 1 : 0.6)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(Theme.Motion.spring(reduceMotion: reduceMotion)) {
                    isVisible = true
                }
            }
    }
}

#Preview {
    PRBadge(kind: "Weight")
        .padding()
        .background(Theme.Color.background)
}
