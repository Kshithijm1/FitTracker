import SwiftUI
import SwiftData
import Charts

private enum TrendRange: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case all = "All"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

/// Weight raw dots + 7-day EMA trend line, 7/30/90/all range toggle, plus
/// measurement logging (PLAN.md §3).
struct BodyProgressView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date) private var allWeights: [WeightEntry]
    @Query(sort: \MeasurementEntry.date, order: .reverse) private var measurements: [MeasurementEntry]

    @State private var range: TrendRange = .month
    @State private var showingLogWeight = false
    @State private var showingLogMeasurement = false

    private var filteredWeights: [WeightEntry] {
        guard let days = range.days else { return allWeights }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return allWeights.filter { $0.date >= cutoff }
    }

    private var trendPoints: [(date: Date, trendKG: Double)] {
        TrendMath.sevenDayEMA(of: filteredWeights.map { ($0.date, $0.weightKG) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Picker("Range", selection: $range) {
                    ForEach(TrendRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if filteredWeights.isEmpty {
                    ContentUnavailableView(
                        "No weigh-ins yet",
                        systemImage: "scalemass",
                        description: Text("Log your weight to start a trend line.")
                    )
                } else {
                    Card {
                        Chart {
                            ForEach(filteredWeights) { entry in
                                PointMark(x: .value("Date", entry.date), y: .value("kg", entry.weightKG))
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .symbolSize(30)
                            }
                            ForEach(trendPoints, id: \.date) { point in
                                LineMark(x: .value("Date", point.date), y: .value("kg", point.trendKG))
                                    .foregroundStyle(Theme.Color.accent)
                                    .interpolationMethod(.monotone)
                            }
                        }
                        .frame(height: 220)
                    }
                }

                Button("Log weight") { showingLogWeight = true }

                Divider().background(Theme.Color.separator)

                HStack {
                    Text("Measurements")
                        .font(Theme.Font.title22)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Button("Add") { showingLogMeasurement = true }
                }

                ForEach(measurements.prefix(10)) { measurement in
                    HStack {
                        Text(measurement.site.rawValue.capitalized)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        Text("\(measurement.valueCM.formatted(.number.precision(.fractionLength(1)))) cm")
                            .foregroundStyle(Theme.Color.textSecondary)
                        Text(measurement.date.formatted(date: .abbreviated, time: .omitted))
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .sheet(isPresented: $showingLogWeight) {
            LogWeightSheet()
        }
        .sheet(isPresented: $showingLogMeasurement) {
            LogMeasurementSheet()
        }
    }
}

extension WeightEntry: Identifiable {}
extension MeasurementEntry: Identifiable {}
