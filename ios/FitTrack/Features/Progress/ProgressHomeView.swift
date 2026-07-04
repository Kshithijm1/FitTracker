import SwiftUI

private enum ProgressSegment: String, CaseIterable {
    case strength = "Strength"
    case body = "Body"
    case nutrition = "Nutrition"
}

struct ProgressHomeView: View {
    @State private var segment: ProgressSegment = .strength

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    ForEach(ProgressSegment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(Theme.Spacing.md)

                switch segment {
                case .strength: StrengthProgressView()
                case .body: BodyProgressView()
                case .nutrition: NutritionProgressView()
                }
            }
            .background(Theme.Color.background)
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressHomeView()
        .modelContainer(for: [WeightEntry.self, SetEntry.self, FoodLog.self], inMemory: true)
}
