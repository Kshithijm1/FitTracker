import Foundation

/// Estimated 1-rep-max and volume math for PR detection and the Strength
/// progress chart. Uses the Epley formula, standard for gym-logging apps.
enum StrengthMath {
    /// `e1RM = weight * (1 + reps / 30)`. Returns raw weight unchanged for
    /// single-rep sets (Epley is undefined/unreliable below that).
    static func estimatedOneRepMax(weightKG: Double, reps: Int) -> Double {
        guard reps > 1 else { return weightKG }
        return weightKG * (1 + Double(reps) / 30)
    }

    static func volume(weightKG: Double, reps: Int) -> Double {
        weightKG * Double(reps)
    }
}
