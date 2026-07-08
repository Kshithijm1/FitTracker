import Observation
import LocalAuthentication

/// Face ID (or passcode fallback) app-lock gate (PLAN.md §5). `isEnabled`
/// persists across launches; `isUnlocked` resets to `false` on every
/// background→foreground transition (`FitTrackApp` calls `lock()` on
/// `.background`), so the gate is real rather than a one-time-per-process check.
@MainActor // <-- ADD THIS TO ISOLATE ALL PROPERTIES AND METHODS TO THE MAIN THREAD
@Observable
final class AppLockController {
    private static let enabledDefaultsKey = "fittrack.appLock.enabled"

    private(set) var isUnlocked = false
    private(set) var lastError: String?

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if isEnabled {
                isUnlocked = false
            }
        }
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    /// Call whenever the scene becomes `.background` so returning to the
    /// foreground always re-prompts (a lock that only checks once per
    /// process launch is not a real lock).
    func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }

    func unlockIfNeeded() async {
        guard isEnabled, !isUnlocked else {
            if !isEnabled { isUnlocked = true }
            return
        }

        let context = LAContext()
        var policyError: NSError?
        // Passcode fallback (not biometrics-only): a user without Face ID/Touch
        // ID enrolled still gets a real lock rather than silently bypassing it.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // Neither biometrics nor a device passcode is set up — there is no
            // credential to gate on, so fail open rather than lock the user out permanently.
            isUnlocked = true
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock FitTrack"
            )
            isUnlocked = success
            lastError = nil
        } catch {
            isUnlocked = false
            lastError = "Authentication failed. Try again."
        }
    }
}
