import SwiftUI

/// Explains what's being requested and why *before* the system HealthKit
/// prompt appears (PLAN.md §3/§7 "clear permission rationale screens").
struct HealthKitPermissionView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Image(systemName: "heart.text.square")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Color.accent)

                Text("Connect Apple Health")
                    .font(Theme.Font.title22)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    bullet("Steps", "Shown on Today alongside your other rings.")
                    bullet("Sleep", "Filled in automatically instead of manual entry.")
                    bullet("Read-only", "FitTrack never writes anything back to Health.")
                    bullet("Stays on-device", "Steps/sleep from Health are never synced to FitTrack's servers — only entries you log manually are (PLAN.md §5).")
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.error)
                }

                Spacer()

                Button(isRequesting ? "Requesting…" : "Continue") {
                    Task { await requestAccess() }
                }
                .disabled(isRequesting)
                .font(Theme.Font.bodyEmphasized17)
                .foregroundStyle(Theme.Color.onAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Color.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.bodyEmphasized17)
                Text(detail).font(Theme.Font.caption13).foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private func requestAccess() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await container.healthKit.requestAuthorization()
            dismiss()
        } catch {
            errorMessage = "Couldn't request Health access. Try again from Settings if this persists."
        }
    }
}
