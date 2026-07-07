import WidgetKit
import SwiftUI

@main
struct FitTrackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayRingsWidget()
        RestTimerLiveActivity()
    }
}

private struct TodayRingsEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

/// Reads the snapshot the main app writes to the shared App Group container
/// (PLAN.md §7 "Today rings widget"). The main app also calls
/// `WidgetCenter.shared.reloadTimelines` after every write, so the ~30-min
/// timeline refresh below is just a fallback for when the app hasn't run.
private struct TodayRingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayRingsEntry {
        TodayRingsEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayRingsEntry) -> Void) {
        completion(TodayRingsEntry(date: .now, snapshot: TodaySnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayRingsEntry>) -> Void) {
        let entry = TodayRingsEntry(date: .now, snapshot: TodaySnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct TodayRingsWidget: Widget {
    let kind = "TodayRingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayRingsProvider()) { entry in
            TodayRingsWidgetView(snapshot: entry.snapshot)
                .containerBackground(WidgetTheme.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Calories left, water, and steps at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayRingsWidgetView: View {
    let snapshot: TodaySnapshot
    @Environment(\.widgetFamily) private var family

    private var fraction: Double {
        guard snapshot.kcalTarget > 0 else { return 0 }
        let consumed = snapshot.kcalTarget - snapshot.kcalRemaining
        return min(max(Double(consumed) / Double(snapshot.kcalTarget), 0), 1)
    }

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                ring
                VStack(alignment: .leading, spacing: 8) {
                    stat(icon: "drop.fill", value: "\(snapshot.waterGlasses)/\(snapshot.waterGoalGlasses)", label: "water")
                    stat(icon: "figure.walk", value: "\(snapshot.steps)", label: "steps")
                }
                Spacer()
            }
            .padding()
        default:
            ring.padding()
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(WidgetTheme.ringTrack, lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(WidgetTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(snapshot.kcalRemaining)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("kcal left")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(WidgetTheme.accent)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

/// Small, self-contained copy of the app's palette — widget extensions
/// can't import the app's `Theme` asset catalog directly, so the handful
/// of colors used here are duplicated rather than sharing a framework.
/// Internal (not `private`) so other files in this extension target — the
/// Live Activity view — can reuse it too.
enum WidgetTheme {
    static let accent = Color(red: 0.784, green: 0.941, blue: 0.290) // #C8F04A
    static let ringTrack = Color(white: 0.5).opacity(0.25)
    static let background = Color(red: 0.047, green: 0.047, blue: 0.055) // #0C0C0E
}
