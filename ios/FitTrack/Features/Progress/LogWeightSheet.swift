import SwiftUI

struct LogWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var weightKG: Double = 75

    var body: some View {
        NavigationStack {
            Form {
                Stepper("\(weightKG.formatted(.number.precision(.fractionLength(1)))) kg", value: $weightKG, in: 20...300, step: 0.1)
            }
            .navigationTitle("Log Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(WeightEntry(weightKG: weightKG))
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
    }
}
