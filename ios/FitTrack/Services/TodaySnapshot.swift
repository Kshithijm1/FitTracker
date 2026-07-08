import Foundation

/// The small slice of Today's state the widget needs. Written by the main
/// app to the shared App Group container whenever Today-relevant data
/// changes; read by `FitTrackWidgets` — this file is a member of both
/// targets (see `ios/project.yml`), never a network or SwiftData model.
struct TodaySnapshot: Codable {
    var kcalRemaining: Int
    var kcalTarget: Int
    var waterGlasses: Int
    var waterGoalGlasses: Int
    var steps: Int
    var stepGoal: Int
    var updatedAt: Date

    static let empty = TodaySnapshot(
        kcalRemaining: 0, kcalTarget: 2000,
        waterGlasses: 0, waterGoalGlasses: 8,
        steps: 0, stepGoal: 8000,
        updatedAt: .now
    )

    private static let suiteName = "group.com.fittrack.shared"
    private static let storageKey = "fittrack.todaySnapshot"

    static func load() -> TodaySnapshot {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(TodaySnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else { return }
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
