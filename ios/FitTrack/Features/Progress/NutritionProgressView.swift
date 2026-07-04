import SwiftUI
import SwiftData
import Charts

/// Calorie/macro adherence bars by week (PLAN.md §3) — one bar per day,
/// colored by how close the day landed to the calorie target.
struct NutritionProgressView: View {
    @Query private var logs: [FoodLog]
    @Query private var goalsList: [Goals]

    private var goals: Goals { goalsList.first ?? Goals() }

    private struct DayTotal: Identifiable {
        let date: Date
        var kcal: Double
        var id: Date { date }
    }

    private var last7Days: [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()

        return days.map { day in
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let total = logs
                .filter { $0.date >= day && $0.date < nextDay }
                .reduce(0.0) { $0 + $1.macroSnapshot.kcal }
            return DayTotal(date: day, kcal: total)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Calorie adherence, last 7 days")
                    .font(Theme.Font.title22)
                    .foregroundStyle(Theme.Color.textPrimary)

                Card {
                    Chart(last7Days) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("kcal", day.kcal)
                        )
                        .foregroundStyle(barColor(for: day.kcal))

                        RuleMark(y: .value("Target", goals.calorieTarget))
                            .foregroundStyle(Theme.Color.textTertiary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 220)
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func barColor(for kcal: Double) -> Color {
        let fraction = kcal / Double(max(goals.calorieTarget, 1))
        switch fraction {
        case ..<0.85, 1.15...: return Theme.Color.warning
        default: return Theme.Color.accent
        }
    }
}
