import Foundation
import UserNotifications
import ActivityKit
import Observation

/// Rest timer surfaced as both a local notification (fires even if the app
/// is backgrounded/killed) and a lock-screen/Dynamic-Island Live Activity
/// (PLAN.md §3/§7).
@MainActor
@Observable
final class RestTimerService {
    private static let notificationID = "fittrack.rest-timer"

    private(set) var endsAt: Date?
    private var tickTask: Task<Void, Never>?
    private var activity: Activity<RestTimerActivityAttributes>?

    var remainingSeconds: Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
    }

    var isRunning: Bool { endsAt != nil }

    func start(seconds: TimeInterval, exerciseName: String = "Rest") {
        cancel()
        let end = Date().addingTimeInterval(seconds)
        endsAt = end
        scheduleNotification(secondsFromNow: seconds)
        startLiveActivity(endsAt: end, exerciseName: exerciseName)
        tickTask = Task { [weak self] in
            while let self, self.isRunning, self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
            }
            self?.endsAt = nil
            await self?.endLiveActivity()
        }
    }

    func cancel() {
        endsAt = nil
        tickTask?.cancel()
        tickTask = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        Task { await endLiveActivity() }
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

    private func startLiveActivity(endsAt: Date, exerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RestTimerActivityAttributes(exerciseName: exerciseName)
        let state = RestTimerActivityAttributes.ContentState(endsAt: endsAt)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: endsAt)
        )
    }

    private func endLiveActivity() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
