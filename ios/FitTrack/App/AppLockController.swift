import Observation
import LocalAuthentication

/// Face ID app-lock gate. Locked by default whenever biometrics are
/// available and enabled in settings; Phase 1 ships the mechanism disabled
/// (`isEnabled == false`) since Settings UI lands in Phase 4.
@Observable
final class AppLockController {
    private(set) var isUnlocked = false
    var isEnabled = false

    func unlockIfNeeded() async {
        guard isEnabled, !isUnlocked else {
            isUnlocked = true
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics enrolled — fail open rather than lock the user out.
            isUnlocked = true
            return
        }
        do {
            isUnlocked = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock FitTrack"
            )
        } catch {
            isUnlocked = false
        }
    }
}
