import SwiftUI

/// Full-screen block shown whenever `AppLockController.isEnabled &&
/// !isUnlocked` (PLAN.md §5). Covers the entire window — including on the
/// very first frame after a background→foreground transition — so locked
/// content is never briefly visible.
struct LockScreenView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Color.accent)
            Text("FitTrack Locked")
                .font(Theme.Font.title22)
                .foregroundStyle(Theme.Color.textPrimary)

            if let lastError = container.appLock.lastError {
                Text(lastError)
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.error)
            }

            Spacer()

            Button("Unlock") {
                Task { await container.appLock.unlockIfNeeded() }
            }
            .font(Theme.Font.bodyEmphasized17)
            .foregroundStyle(Theme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
        .task {
            await container.appLock.unlockIfNeeded()
        }
    }
}
