import ActivityKit

/// Shared between the app (starts/ends the activity) and `FitTrackWidgets`
/// (renders it) — same sharing convention as `TodaySnapshot.swift`, see
/// `ios/project.yml`. Lock-screen/Dynamic-Island rest timer (PLAN.md §3/§7).
struct RestTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endsAt: Date
    }

    var exerciseName: String
}
