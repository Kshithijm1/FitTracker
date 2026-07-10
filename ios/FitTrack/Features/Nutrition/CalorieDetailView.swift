import SwiftUI
import SwiftData
import Charts

/// Calorie deep-dive behind the Nutrition header. Day mode: today's slot
/// breakdown and macros. Week mode: a bar per day (tap a bar for that
/// day's breakdown) with chevrons to walk back through previous weeks.
struct CalorieDetailView: View {
    private enum Mode: String, CaseIterable { case day = "Day", week = "Week" }

    @Environment(\.modelContext) private var context
    @Query private var goalsList: [Goals]

    @State private var mode: Mode = .day
    /// 0 = this week, 1 = last week, …
    @State private var weeksBack = 0
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var dayLogs: [FoodLog] = []
    @State private var weekTotals: [(day: Date, kcal: Double)] = []
    @State private var foodNamesByID: [UUID: String] = [:]

    private var goals: Goals { goalsList.first ?? Goals() }
    private var calendar: Calendar { Calendar.current }

    private var weekStart: Date {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek)!
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .week {
                    weekNavigator
                    weekChart
                }

                dayBreakdown
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Color.background)
        .navigationTitle("Calories")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(mode.rawValue)-\(weeksBack)-\(selectedDay.timeIntervalSince1970)") {
            reload()
        }
    }

    // MARK: - Week UI

    private var weekNavigator: some View {
        HStack {
            Button {
                weeksBack += 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous week")

            Spacer()
            Text(weekTitle)
                .font(Theme.Font.bodyEmphasized17)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()

            Button {
                weeksBack = max(weeksBack - 1, 0)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(weeksBack == 0)
            .accessibilityLabel("Next week")
        }
        .foregroundStyle(Theme.Color.accent)
    }

    private var weekTitle: String {
        if weeksBack == 0 { return "This week" }
        if weeksBack == 1 { return "Last week" }
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        return "\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var weekChart: some View {
        Card {
            Chart(weekTotals, id: \.day) { entry in
                BarMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("kcal", entry.kcal)
                )
                .foregroundStyle(
                    calendar.isDate(entry.day, inSameDayAs: selectedDay)
                        ? Theme.Color.accent
                        : Theme.Color.accent.opacity(0.35)
                )
                .cornerRadius(4)

                RuleMark(y: .value("Target", goals.calorieTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            let origin = geometry[proxy.plotFrame!].origin
                            if let day: Date = proxy.value(atX: location.x - origin.x) {
                                selectedDay = calendar.startOfDay(for: day)
                                Haptics.light()
                            }
                        }
                }
            }
            .accessibilityLabel("Weekly calories bar chart. Tap a bar to see that day.")
        }
    }

    // MARK: - Day breakdown

    private var dayBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            let displayDay = mode == .day ? calendar.startOfDay(for: .now) : selectedDay
            let total = dayLogs.reduce(0.0) { $0 + $1.macroSnapshot.kcal }
            let protein = dayLogs.reduce(0.0) { $0 + $1.macroSnapshot.protein }
            let carbs = dayLogs.reduce(0.0) { $0 + $1.macroSnapshot.carbs }
            let fat = dayLogs.reduce(0.0) { $0 + $1.macroSnapshot.fat }

            HStack {
                Text(calendar.isDateInToday(displayDay) ? "Today" : displayDay.formatted(date: .complete, time: .omitted))
                    .font(Theme.Font.title22)
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Text("\(Int(total)) / \(goals.calorieTarget) kcal")
                    .font(Theme.Font.numeral(17))
                    .foregroundStyle(total > Double(goals.calorieTarget) ? Theme.Color.warning : Theme.Color.textSecondary)
            }

            Card {
                HStack {
                    macroStat("\(Int(protein))g", "protein")
                    macroStat("\(Int(carbs))g", "carbs")
                    macroStat("\(Int(fat))g", "fat")
                }
            }

            if dayLogs.isEmpty {
                Card {
                    Text("Nothing logged this day.")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    let slotLogs = dayLogs.filter { $0.slot == slot }
                    if !slotLogs.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(slot == .snack ? "Snacks" : slot.rawValue.capitalized)
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                ForEach(slotLogs) { log in
                                    HStack {
                                        Text(foodNamesByID[log.foodItemID] ?? "Food")
                                            .font(Theme.Font.body17)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(Int(log.macroSnapshot.kcal)) kcal")
                                            .font(Theme.Font.caption13)
                                            .foregroundStyle(Theme.Color.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func macroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.numeral(18))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(label)
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func reload() {
        let displayDay = mode == .day ? calendar.startOfDay(for: .now) : selectedDay
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: displayDay)!
        dayLogs = ((try? context.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= displayDay && $0.date < dayEnd },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []).filter { $0.deletedAt == nil }

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let weekLogs = ((try? context.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= weekStart && $0.date < weekEnd }
        ))) ?? []).filter { $0.deletedAt == nil }
        var byDay: [Date: Double] = [:]
        for log in weekLogs {
            byDay[calendar.startOfDay(for: log.date), default: 0] += log.macroSnapshot.kcal
        }
        weekTotals = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return (day, byDay[day] ?? 0)
        }

        let ids = Set(dayLogs.map(\.foodItemID))
        if !ids.isEmpty {
            let items = (try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
            foodNamesByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        }

        // When flipping weeks, keep the selected day inside the shown week.
        if mode == .week, !calendar.isDate(selectedDay, equalTo: weekStart, toGranularity: .weekOfYear) {
            selectedDay = weeksBack == 0 ? calendar.startOfDay(for: .now) : weekStart
        }
    }
}
