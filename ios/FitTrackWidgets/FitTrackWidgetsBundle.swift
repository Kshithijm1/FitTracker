import WidgetKit
import SwiftUI

/// Phase 1 ships this target as a minimal buildable placeholder so the app
/// target's widget-extension embed and entitlements wiring are correct from
/// day one. The real Today-rings widget and rest-timer Live Activity land
/// in Phase 3 per PLAN.md; `PlaceholderWidget` is removed at that point.
@main
struct FitTrackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

private struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

private struct PlaceholderWidget: Widget {
    let kind = "FitTrackPlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("FitTrack")
        }
        .configurationDisplayName("FitTrack")
        .description("Coming in Phase 3.")
    }
}
