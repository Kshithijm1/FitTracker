import Testing
@testable import FitTrack

struct MacroMathTests {
    @Test func remainingCaloriesClampsAtZero() {
        #expect(MacroMath.remaining(target: 2000, consumed: 2400) == 0)
    }

    @Test func remainingCaloriesSubtractsConsumed() {
        #expect(MacroMath.remaining(target: 2000, consumed: 570) == 1430)
    }

    @Test func fractionConsumedClampsToOne() {
        #expect(MacroMath.fractionConsumed(target: 2000, consumed: 3000) == 1)
    }

    @Test func fractionConsumedZeroTargetIsZero() {
        #expect(MacroMath.fractionConsumed(target: 0, consumed: 100) == 0)
    }

    @Test func scaleMacrosHalvesAt50Grams() {
        let per100g = MacroSet(kcal: 200, protein: 20, carbs: 10, fat: 5)
        let scaled = MacroMath.scaleMacros(per100g: per100g, quantityG: 50)
        #expect(scaled.kcal == 100)
        #expect(scaled.protein == 10)
    }
}
