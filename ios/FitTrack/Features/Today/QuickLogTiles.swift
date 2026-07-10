import SwiftUI
import SwiftData

/// The quick-loggable metrics a Home tile can point at. Users pick any 3;
/// each logs in one or two taps via a preset sheet.
enum QuickMetric: String, CaseIterable, Identifiable {
    case water, steps, sleep, weight, protein, calories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Water"
        case .steps: return "Steps"
        case .sleep: return "Sleep"
        case .weight: return "Weight"
        case .protein: return "Protein"
        case .calories: return "Quick kcal"
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .steps: return "figure.walk"
        case .sleep: return "moon.fill"
        case .weight: return "scalemass.fill"
        case .protein: return "fork.knife"
        case .calories: return "flame.fill"
        }
    }

    /// Reads the saved tile selection ("water,steps,sleep").
    static func selection(from stored: String) -> [QuickMetric] {
        let parsed = stored.split(separator: ",").compactMap { QuickMetric(rawValue: String($0)) }
        var result = parsed
        // Self-heal: always exactly 3 distinct tiles.
        for candidate in QuickMetric.allCases where result.count < 3 && !result.contains(candidate) {
            result.append(candidate)
        }
        return Array(result.prefix(3))
    }
}

/// The row of three user-configurable quick-log tiles on Home. Tap = log
/// sheet with presets; long-press = swap the tile for another metric.
struct QuickLogTiles: View {
    @Environment(\.modelContext) private var context
    @AppStorage("quickTiles") private var storedTiles = "water,steps,sleep"

    @State private var activeSheet: QuickMetric?
    @State private var replacingSlot: Int?

    // Today's values, queried live.
    @Query private var todayWater: [WaterEntry]
    @Query private var todaySleep: [SleepEntry]
    @Query private var todaySteps: [StepsCache]
    @Query private var todayWeights: [WeightEntry]
    @Query private var todayLogs: [FoodLog]
    @Query private var goalsList: [Goals]
    @Query private var profiles: [UserProfile]

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _todayWater = Query(filter: #Predicate<WaterEntry> { $0.date >= start && $0.date < end })
        _todaySleep = Query(filter: #Predicate<SleepEntry> { $0.date >= start && $0.date < end })
        _todaySteps = Query(filter: #Predicate<StepsCache> { $0.date >= start && $0.date < end })
        _todayWeights = Query(filter: #Predicate<WeightEntry> { $0.date >= start && $0.date < end })
        _todayLogs = Query(filter: #Predicate<FoodLog> { $0.date >= start && $0.date < end })
    }

    private var goals: Goals { goalsList.first ?? Goals() }
    private var profile: UserProfile? { profiles.first }
    private var tiles: [QuickMetric] { QuickMetric.selection(from: storedTiles) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(tiles.enumerated()), id: \.element) { slot, metric in
                QuickTile(
                    metric: metric,
                    valueText: valueText(for: metric),
                    progress: progress(for: metric)
                ) {
                    activeSheet = metric
                } onSwap: {
                    replacingSlot = slot
                }
            }
        }
        .sheet(item: $activeSheet) { metric in
            QuickLogSheet(metric: metric, goals: goals, profile: profile)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { replacingSlot != nil },
            set: { if !$0 { replacingSlot = nil } }
        )) {
            TilePickerSheet(currentTiles: tiles) { newMetric in
                if let slot = replacingSlot {
                    var updated = tiles
                    updated[slot] = newMetric
                    storedTiles = updated.map(\.rawValue).joined(separator: ",")
                }
                replacingSlot = nil
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Values

    private var waterML: Int { todayWater.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.amountML } }
    private var sleepMinutes: Int { todaySleep.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.minutes } }
    private var steps: Int { todaySteps.first?.steps ?? 0 }
    private var proteinG: Double { todayLogs.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.macroSnapshot.protein } }
    private var kcal: Double { todayLogs.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.macroSnapshot.kcal } }

    private func valueText(for metric: QuickMetric) -> String {
        switch metric {
        case .water:
            return Units.formatVolume(waterML, unit: profile?.volumeUnit ?? .milliliters)
        case .steps:
            return steps.formatted(.number.notation(.compactName))
        case .sleep:
            return sleepMinutes > 0 ? "\(sleepMinutes / 60)h \(sleepMinutes % 60)m" : "--"
        case .weight:
            if let latest = todayWeights.filter({ $0.deletedAt == nil }).max(by: { $0.date < $1.date }) {
                return Units.formatWeight(latest.weightKG, unit: profile?.unitPreference ?? .imperial)
            }
            return "--"
        case .protein:
            return "\(Int(proteinG))g"
        case .calories:
            return "\(Int(kcal))"
        }
    }

    private func progress(for metric: QuickMetric) -> Double {
        switch metric {
        case .water: return Double(waterML) / Double(max(goals.waterML, 1))
        case .steps: return Double(steps) / Double(max(goals.stepTarget, 1))
        case .sleep: return Double(sleepMinutes) / Double(max(goals.sleepMinutesTarget, 1))
        case .weight: return todayWeights.contains { $0.deletedAt == nil } ? 1 : 0
        case .protein: return proteinG / Double(max(goals.proteinG, 1))
        case .calories: return kcal / Double(max(goals.calorieTarget, 1))
        }
    }
}

private struct QuickTile: View {
    let metric: QuickMetric
    let valueText: String
    let progress: Double
    let onTap: () -> Void
    let onSwap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                VStack(spacing: Theme.Spacing.xs) {
                    ProgressRing(progress: progress, lineWidth: 5, color: Theme.Color.accent)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: metric.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                    Text(valueText)
                        .font(Theme.Font.numeral(14))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(metric.title)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Change metric", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
        }
        .accessibilityLabel("\(metric.title), \(valueText)")
        .accessibilityHint("Tap to log. Long-press to change metric.")
    }
}

// MARK: - Log sheet

/// Preset-first logging: the common amounts are one tap, custom entry is
/// right below — never a multi-screen form.
private struct QuickLogSheet: View {
    let metric: QuickMetric
    let goals: Goals
    let profile: UserProfile?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var customValue: Double = 0
    @State private var sleepHours = 8.0
    @State private var sleepMinutesPart = 0.0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                presets
                customEntry
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)
            .navigationTitle("Log \(metric.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { customValue = defaultCustomValue }
    }

    @ViewBuilder
    private var presets: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Quick add")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(presetOptions, id: \.label) { preset in
                    Button {
                        log(preset.value)
                    } label: {
                        Text(preset.label)
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var customEntry: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Custom")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)

            if metric == .sleep {
                HStack {
                    CompactStepper(value: $sleepHours, step: 0.5, label: "hours") { "\(String(format: "%g", $0))h" }
                    Button("Log") { log(sleepHours * 60) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Color.accent)
                        .foregroundStyle(Theme.Color.onAccent)
                }
            } else {
                HStack {
                    CompactStepper(value: $customValue, step: customStep, label: metric.title) {
                        "\(Int($0)) \(customUnitLabel)"
                    }
                    Button("Log") { log(customValue) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Color.accent)
                        .foregroundStyle(Theme.Color.onAccent)
                }
            }
        }
    }

    // MARK: presets per metric (values in storage units)

    private struct Preset { let label: String; let value: Double }

    private var volumeUnit: VolumeUnit { profile?.volumeUnit ?? .milliliters }
    private var weightUnit: UnitPreference { profile?.unitPreference ?? .imperial }

    private var presetOptions: [Preset] {
        switch metric {
        case .water:
            if volumeUnit == .fluidOunces {
                return [Preset(label: "8 oz", value: 237), Preset(label: "16 oz", value: 473), Preset(label: "24 oz", value: 710)]
            }
            return [Preset(label: "250 ml", value: 250), Preset(label: "500 ml", value: 500), Preset(label: "750 ml", value: 750)]
        case .steps:
            return [Preset(label: "1k", value: 1000), Preset(label: "2.5k", value: 2500), Preset(label: "5k", value: 5000)]
        case .sleep:
            return [Preset(label: "6h", value: 360), Preset(label: "7h", value: 420), Preset(label: "8h", value: 480)]
        case .weight:
            return [] // weight has no sensible presets — custom only
        case .protein:
            return [Preset(label: "25g", value: 25), Preset(label: "30g", value: 30), Preset(label: "40g", value: 40)]
        case .calories:
            return [Preset(label: "100", value: 100), Preset(label: "250", value: 250), Preset(label: "500", value: 500)]
        }
    }

    private var customStep: Double {
        switch metric {
        case .water: return volumeUnit == .fluidOunces ? 59 : 50 // ≈2 oz
        case .steps: return 500
        case .sleep: return 30
        case .weight: return weightUnit == .imperial ? 1 : 0.5 // display units
        case .protein: return 5
        case .calories: return 50
        }
    }

    private var defaultCustomValue: Double {
        switch metric {
        case .water: return 250
        case .steps: return 2000
        case .sleep: return 480
        case .weight:
            let latest = try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first
            return Units.displayWeight(latest?.weightKG ?? 75, unit: weightUnit).rounded()
        case .protein: return 30
        case .calories: return 200
        }
    }

    private var customUnitLabel: String {
        switch metric {
        case .water: return "ml"
        case .steps: return "steps"
        case .sleep: return "min"
        case .weight: return Units.weightLabel(weightUnit)
        case .protein: return "g"
        case .calories: return "kcal"
        }
    }

    private func log(_ value: Double) {
        switch metric {
        case .water:
            context.insert(WaterEntry(amountML: Int(value)))
        case .steps:
            // Manual steps replace today's cache (HealthKit refresh will
            // overwrite with the authoritative number if connected).
            let start = Calendar.current.startOfDay(for: .now)
            if let cache = try? context.fetch(FetchDescriptor<StepsCache>(
                predicate: #Predicate { $0.date >= start }
            )).first {
                cache.steps += Int(value)
            } else {
                context.insert(StepsCache(date: start, steps: Int(value), source: .manual))
            }
        case .sleep:
            context.insert(SleepEntry(minutes: Int(value)))
        case .weight:
            // Custom stepper runs in the user's display unit; storage is kg.
            context.insert(WeightEntry(weightKG: Units.weightToKG(value, unit: weightUnit)))
        case .protein:
            let macros = MacroSet(kcal: value * 4, protein: value, carbs: 0, fat: 0)
            let item = FoodItem(name: "Protein (quick add)", source: .custom, per100g: macros)
            context.insert(item)
            context.insert(FoodLog(slot: .snack, foodItemID: item.id, quantityG: 100, macroSnapshot: macros))
        case .calories:
            let macros = MacroSet(kcal: value, protein: 0, carbs: 0, fat: 0)
            let item = FoodItem(name: "Quick calories", source: .custom, per100g: macros)
            context.insert(item)
            context.insert(FoodLog(slot: .snack, foodItemID: item.id, quantityG: 100, macroSnapshot: macros))
        }
        try? context.save()
        Haptics.light()
        dismiss()
    }
}

// MARK: - Tile picker

private struct TilePickerSheet: View {
    let currentTiles: [QuickMetric]
    let onPick: (QuickMetric) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(QuickMetric.allCases) { metric in
                Button {
                    onPick(metric)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: metric.icon)
                            .foregroundStyle(Theme.Color.accent)
                            .frame(width: 28)
                        Text(metric.title)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        if currentTiles.contains(metric) {
                            Text("On Home")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
