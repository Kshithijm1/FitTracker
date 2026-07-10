import Foundation

/// Deterministic workout-energy estimates using the standard MET formula
/// `kcal/min = MET × 3.5 × bodyweightKG / 200`. Pure math, no imports —
/// unit-testable, and the reason calorie estimates work fully offline.
/// (The AI layer only adds a narrative on top; it never invents numbers.)
enum CalorieBurnMath {

    /// Resistance training including normal rest between sets.
    static let strengthMET = 4.5

    /// MET for a cardio set given what was recorded. Speed-based mapping
    /// follows the Compendium of Physical Activities buckets.
    static func cardioMET(speedKPH: Double, inclinePct: Double) -> Double {
        let base: Double
        switch speedKPH {
        case ..<0.1: base = 7.0        // duration-only cardio (bike, rower default)
        case ..<4.5: base = 3.0        // easy walk
        case ..<6.5: base = 4.3        // brisk walk
        case ..<8.0: base = 7.0        // jog
        case ..<9.7: base = 9.8        // run
        case ..<11.3: base = 11.0
        default: base = 12.5
        }
        // ~0.6 MET per percent incline while moving (treadmill grade rule of thumb).
        let inclineBonus = speedKPH > 0.1 ? inclinePct * 0.6 : 0
        return base + inclineBonus
    }

    /// Total estimate for a finished workout.
    /// - Cardio/time sets burn at their own MET for their recorded duration.
    /// - Everything else (the strength portion) burns at `strengthMET` for
    ///   the remaining session time.
    static func workoutKcal(
        totalDurationSec: Int,
        cardioSets: [(durationSec: Int, speedKPH: Double, inclinePct: Double)],
        bodyweightKG: Double
    ) -> Int {
        let weight = bodyweightKG > 0 ? bodyweightKG : 75 // sensible default until a weigh-in exists
        let kcalPerMinuteFactor = 3.5 * weight / 200

        let cardioSeconds = cardioSets.reduce(0) { $0 + $1.durationSec }
        let cardioKcal = cardioSets.reduce(0.0) { acc, set in
            acc + cardioMET(speedKPH: set.speedKPH, inclinePct: set.inclinePct)
                * kcalPerMinuteFactor * Double(set.durationSec) / 60
        }

        let strengthSeconds = max(totalDurationSec - cardioSeconds, 0)
        let strengthKcal = strengthMET * kcalPerMinuteFactor * Double(strengthSeconds) / 60

        return max(Int((cardioKcal + strengthKcal).rounded()), 0)
    }
}
