import SwiftUI

/// User-selectable override for light/dark, independent of the system
/// setting. Stored under the `"appearanceMode"` `@AppStorage` key.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Single source of truth for color, type, spacing, radius, and motion
/// tokens. Views should never hardcode a hex value, font size, or spring —
/// they reach through `Theme` so the whole app restyles from one place.
enum Theme {

    // MARK: - Color
    // Dynamic colors are defined in Assets.xcassets (Colors/) with explicit
    // Any/Dark appearances; these accessors are the only import point.
    enum Color {
        /// Base canvas. Dark: true black #0C0C0E. Light: #FAFAF9.
        static let background = SwiftUI.Color("Background", bundle: .main)
        /// First elevation above background (cards, rows).
        static let surface = SwiftUI.Color("Surface", bundle: .main)
        /// Second elevation (nested cards, pressed states) — replaces shadows.
        static let surface2 = SwiftUI.Color("Surface2", bundle: .main)
        /// Hairline separators; never opaque black/white.
        static let separator = SwiftUI.Color("Separator", bundle: .main)

        static let textPrimary = SwiftUI.Color("TextPrimary", bundle: .main)
        static let textSecondary = SwiftUI.Color("TextSecondary", bundle: .main)
        static let textTertiary = SwiftUI.Color("TextTertiary", bundle: .main)

        /// The one accent: confident lime-green. Primary actions, completed
        /// rings, PR badges only — never decorative.
        static let accent = SwiftUI.Color("Accent", bundle: .main)
        /// Text/icons drawn on top of a solid `accent` fill (near-black, not white).
        static let onAccent = SwiftUI.Color("OnAccent", bundle: .main)

        static let success = SwiftUI.Color("Success", bundle: .main)
        static let warning = SwiftUI.Color("Warning", bundle: .main)
        static let error = SwiftUI.Color("Error", bundle: .main)

        /// Track color behind rings/progress bars before fill.
        static let ringTrack = SwiftUI.Color("RingTrack", bundle: .main)
    }

    // MARK: - Typography
    // SF Pro Rounded for numerals/rings (via .rounded design), SF Pro (default)
    // for everything else. Sizes fixed here; Dynamic Type scaling is applied
    // by callers via `.font(Theme.Font.body)` (already relative, scales with
    // the system content size category).
    enum Font {
        static let display34 = SwiftUI.Font.system(size: 34, weight: .bold, design: .rounded)
        static let display28 = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title22 = SwiftUI.Font.system(size: 22, weight: .semibold, design: .default)
        static let body17 = SwiftUI.Font.system(size: 17, weight: .regular, design: .default)
        static let bodyEmphasized17 = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        static let caption13 = SwiftUI.Font.system(size: 13, weight: .medium, design: .default)

        /// Numerals inside rings/stat tiles: rounded design at a given weight.
        static func numeral(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let full: CGFloat = 999
    }

    // MARK: - Motion
    // Standard spring for rings, set-check bounce, PR badge. All motion is
    // interruptible and gated on `accessibilityReduceMotion` at the call
    // site via `Theme.Motion.spring(reduceMotion:)`.
    enum Motion {
        static let standardResponse: Double = 0.3
        static let standardDamping: Double = 0.8

        static func spring(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: standardResponse, dampingFraction: standardDamping)
        }

        /// Short, snappy variant for high-frequency taps (set checkmarks, +1 water).
        static func quickSpring(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.75)
        }
    }
}
