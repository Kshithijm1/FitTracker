import Foundation
import Testing
@testable import FitTrack

struct TrendMathTests {
    @Test func emptyInputProducesEmptyTrend() {
        #expect(TrendMath.sevenDayEMA(of: []).isEmpty)
    }

    @Test func firstPointSeedsTrendAtRawValue() {
        let day0 = Date()
        let result = TrendMath.sevenDayEMA(of: [(day0, 80.0)])
        #expect(result.count == 1)
        #expect(result[0].trendKG == 80.0)
    }

    @Test func trendMovesTowardNewValueButDoesNotJump() {
        let base = Date()
        let entries: [(date: Date, weightKG: Double)] = [
            (base, 80.0),
            (base.addingTimeInterval(86400), 79.0),
        ]
        let result = TrendMath.sevenDayEMA(of: entries)
        #expect(result.count == 2)
        // alpha = 0.25, so trend should land 25% of the way from 80 to 79.
        #expect(abs(result[1].trendKG - 79.75) < 0.001)
    }
}
