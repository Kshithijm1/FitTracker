import SwiftUI

/// Standard surface container used for every card-shaped block (quick-add,
/// continue-workout, recents grid cells). Radius/spacing from `Theme`; no
/// shadow — elevation reads via `Theme.Color.surface` against the
/// background tone.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}
