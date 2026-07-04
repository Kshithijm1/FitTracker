import Foundation

/// Body-weight trend line math (Progress > Body). Pure function over
/// `(date, weightKG)` pairs sorted ascending by date.
enum TrendMath {
    /// 7-day exponential moving average, seeded with the first raw value.
    /// `alpha = 2 / (N + 1)` with N = 7, matching typical weight-trend apps
    /// (Trendweight/Happy Scale convention).
    static func sevenDayEMA(of entries: [(date: Date, weightKG: Double)]) -> [(date: Date, trendKG: Double)] {
        guard let first = entries.first else { return [] }
        let alpha = 2.0 / (7.0 + 1.0)
        var trend = first.weightKG
        var result: [(date: Date, trendKG: Double)] = [(first.date, trend)]

        for entry in entries.dropFirst() {
            trend = alpha * entry.weightKG + (1 - alpha) * trend
            result.append((entry.date, trend))
        }
        return result
    }
}
