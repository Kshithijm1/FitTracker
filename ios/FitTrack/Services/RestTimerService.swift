import Foundation
import UserNotifications
import Observation

/// Rest timer surfaced as a local notification (Phase 1) so it still fires
/// if the user backgrounds the app; a lock-screen Live Activity replaces
/// the notification banner in Phase 3 (PLAN.md §3/§7).
@MainActor
@Observable
final class RestTimerService {
    private static let notificationID = "fittrack.rest-timer"

    private(set) var endsAt: Date?
    private var tickTask: Task<Void, Never>?

    var remainingSeconds: Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
    }

    var isRunning: Bool { endsAt != nil }

    func start(seconds: TimeInterval) {
        cancel()
        let end = Date().addingTimeInterval(seconds)
        endsAt = end
        scheduleNotification(secondsFromNow: seconds)
        tickTask = Task { [weak self] in
            while let self, self.isRunning, self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
            }
            self?.endsAt = nil
        }
    }

    func cancel() {
        endsAt = nil
        tickTask?.cancel()
        tickTask = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func scheduleNotification(secondsFromNow: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
