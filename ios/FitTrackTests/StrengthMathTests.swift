import Testing
@testable import FitTrack

struct StrengthMathTests {
    @Test func e1RMUsesEpleyFormula() {
        // 100kg x 8 reps -> 100 * (1 + 8/30) = 126.667
        let e1RM = StrengthMath.estimatedOneRepMax(weightKG: 100, reps: 8)
        #expect(abs(e1RM - 126.667) < 0.01)
    }

    @Test func e1RMForSingleRepReturnsRawWeight() {
        #expect(StrengthMath.estimatedOneRepMax(weightKG: 140, reps: 1) == 140)
    }

    @Test func volumeMultipliesWeightByReps() {
        #expect(StrengthMath.volume(weightKG: 100, reps: 8) == 800)
    }
}
