import SwiftUI
import SwiftData
import Charts

/// Day / Week / Month progress at the top of Home: weight change, workout
/// count, calorie adherence — the "how am I actually doing" answer without
/// opening a single chart screen.
struct PeriodProgressCard: View {
    enum Period: String, CaseIterable, Identifiable {
        case day = "Today", week = "Week", month = "Month"
        var id: String { rawValue }

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var goalsList: [Goals]

    @State private var period: Period = .week
    @State private var stats = PeriodStats()

    private var profile: UserProfile? { profiles.first }
    private var goals: Goals { goalsList.first ?? Goals() }

    struct PeriodStats {
        var weightChangeKG: Double?
        var workouts = 0
        var completedSets = 0
        var caloriesBurned = 0
        var avgKcal: Double?
        var dailyKcal: [(day: Date, kcal: Double)] = []
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack(spacing: Theme.Spacing.sm) {
                    headline(
                        value: weightChangeText,
                        label: period == .day ? "weight today" : "weight change",
                        emphasized: true
                    )
                    Divider().frame(height: 36)
                    headline(value: "\(stats.workouts)", label: stats.workouts == 1 ? "workout" : "workouts")
                    Divider().frame(height: 36)
                    headline(
                        value: stats.avgKcal.map { "\(Int($0))" } ?? "--",
                        label: period == .day ? "kcal eaten" : "avg kcal/day"
                    )
                }

                if period != .day && stats.dailyKcal.contains(where: { $0.kcal > 0 }) {
                    Chart(stats.dailyKcal, id: \.day) { entry in
                        BarMark(
                            x: .value("Day", entry.day, unit: .day),
                            y: .value("kcal", entry.kcal)
                        )
                        .foregroundStyle(Theme.Color.accent.opacity(0.85))
                        .cornerRadius(3)

                        RuleMark(y: .value("Target", goals.calorieTarget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                                .font(Theme.Font.caption13)
                        }
                    }
                    .frame(height: 64)
                    .accessibilityLabel("Daily calories chart")
                }
            }
        }
        .task(id: period) { recompute() }
        .onAppear { recompute() }
    }

    private var weightChangeText: String {
        guard let change = stats.weightChangeKG else { return "--" }
        let unit = profile?.unitPreference ?? .imperial
        let display = Units.displayWeight(change, unit: unit)
        if period == .day { return Units.formatWeight(abs(change), unit: unit) }
        return String(format: "%+.1f %@", display, Units.weightLabel(unit))
    }

    private func headline(value: String, label: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Font.numeral(20))
                .foregroundStyle(emphasized ? Theme.Color.accent : Theme.Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// One fetch pass per period switch — not per render.
    private func recompute() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let periodStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: todayStart)!
        var result = PeriodStats()

        // Weight: latest in period vs. last known before the period
        // (falling back to first in period) — measures real movement.
        let weights = ((try? context.fetch(FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.deletedAt == nil }
        let inPeriod = weights.filter { $0.date >= periodStart }
        if period == .day {
            result.weightChangeKG = inPeriod.last?.weightKG
        } else if let latest = inPeriod.last {
            let baseline = weights.last(where: { $0.date < periodStart }) ?? inPeriod.first
            if let baseline, baseline.id != latest.id {
                result.weightChangeKG = latest.weightKG - baseline.weightKG
            }
        }

        // Workouts
        let workouts = ((try? context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil && $0.startedAt >= periodStart }
        ))) ?? []).filter { $0.deletedAt == nil }
        result.workouts = workouts.count
        result.completedSets = workouts.reduce(0) { $0 + $1.items.flatMap(\.sets).filter(\.isCompleted).count }
        result.caloriesBurned = workouts.reduce(0) { $0 + $1.caloriesBurned }

        // Calories per day
        let logs = ((try? context.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= periodStart }
        ))) ?? []).filter { $0.deletedAt == nil }
        var byDay: [Date: Double] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            byDay[day, default: 0] += log.macroSnapshot.kcal
        }
        result.dailyKcal = (0..<period.days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: periodStart) else { return nil }
            return (day, byDay[day] ?? 0)
        }
        if period == .day {
            result.avgKcal = byDay[todayStart] ?? 0
        } else {
            // Average over days that actually have logs — an empty day is
            // more likely "didn't log" than "ate nothing".
            let logged = result.dailyKcal.filter { $0.kcal > 0 }
            result.avgKcal = logged.isEmpty ? nil : logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
        }

        stats = result
    }
}
