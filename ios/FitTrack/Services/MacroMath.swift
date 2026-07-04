import Foundation

/// Pure calorie/macro arithmetic for the Today ring and Nutrition progress
/// bars. No SwiftData/UIKit imports — kept trivially unit-testable.
enum MacroMath {
    /// Calories/grams left today, clamped at zero (never shows negative "left").
    static func remaining(target: Int, consumed: Int) -> Int {
        max(target - consumed, 0)
    }

    static func remaining(target: Double, consumed: Double) -> Double {
        max(target - consumed, 0)
    }

    /// 0...1 fraction consumed, for ring/bar fills. Clamped so overeating
    /// doesn't overflow the ring past a full circle.
    static func fractionConsumed(target: Int, consumed: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(consumed) / Double(target), 0), 1)
    }

    static func scaleMacros(per100g: MacroSet, quantityG: Double) -> MacroSet {
        let factor = quantityG / 100
        return MacroSet(
            kcal: per100g.kcal * factor,
            protein: per100g.protein * factor,
            carbs: per100g.carbs * factor,
            fat: per100g.fat * factor
        )
    }
}
