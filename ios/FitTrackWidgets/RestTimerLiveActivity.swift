import ActivityKit
import WidgetKit
import SwiftUI

/// Lock-screen + Dynamic Island presentation for the rest timer started by
/// `RestTimerService` (PLAN.md §3/§7). `Text(timerInterval:)` counts down
/// live without the extension re-rendering on a timer of its own.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(WidgetTheme.background)
                .activitySystemActionForegroundColor(WidgetTheme.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.exerciseName, systemImage: "timer")
                        .foregroundStyle(WidgetTheme.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(until: context.state.endsAt)
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(WidgetTheme.accent)
            } compactTrailing: {
                countdownText(until: context.state.endsAt)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(WidgetTheme.accent)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<RestTimerActivityAttributes>) -> some View {
        HStack {
            Label(context.attributes.exerciseName, systemImage: "timer")
                .foregroundStyle(.white)
            Spacer()
            countdownText(until: context.state.endsAt)
                .foregroundStyle(WidgetTheme.accent)
        }
        .padding()
    }

    private func countdownText(until endsAt: Date) -> some View {
        Text(timerInterval: Date.now...endsAt, countsDown: true)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}
