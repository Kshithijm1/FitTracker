import SwiftUI

/// Shown whenever the scene isn't `.active` (about to background, or
/// mid-transition) so health/nutrition data is never visible in the
/// app-switcher snapshot (PLAN.md §5 "sensitive screens excluded from
/// app-switcher snapshot"). Applies regardless of the Face ID lock setting
/// — this is about the OS-level snapshot, not the app-lock feature.
struct PrivacyCoverView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Color.accent)
            Text("FitTrack")
                .font(Theme.Font.display28)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
    }
}
