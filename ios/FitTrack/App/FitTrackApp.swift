import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @State private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environment(container)
                .task {
                    await container.bootstrap()
                    if container.auth.isSignedIn {
                        await container.syncEngine.syncNow()
                    }
                    if container.healthKit.hasRequestedAccess {
                        await container.healthKit.refreshToday()
                    }
                }
        }
        .modelContainer(container.modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if container.auth.isSignedIn {
                    Task { await container.syncEngine.syncNow() }
                }
                if container.healthKit.hasRequestedAccess {
                    Task { await container.healthKit.refreshToday() }
                }
            case .background:
                // Re-arms the Face ID gate for the next foreground and
                // ensures the app-switcher snapshot never captures locked
                // content (PLAN.md §5).
                container.appLock.lock()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

/// Composes the privacy cover (any non-`.active` phase), the Face ID lock
/// gate, and the real app content — in that priority order.
private struct RootContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if scenePhase != .active {
                PrivacyCoverView()
            } else if container.appLock.isEnabled && !container.appLock.isUnlocked {
                LockScreenView()
            } else {
                RootView()
            }
        }
    }
}
