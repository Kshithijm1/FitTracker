import SwiftUI

struct LogMeasurementSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var site: MeasurementSite = .waist
    @State private var valueCM: Double = 80

    var body: some View {
        NavigationStack {
            Form {
                Picker("Site", selection: $site) {
                    ForEach(MeasurementSite.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Stepper("\(valueCM.formatted(.number.precision(.fractionLength(1)))) cm", value: $valueCM, in: 10...200, step: 0.5)
            }
            .navigationTitle("Log Measurement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(MeasurementEntry(site: site, valueCM: valueCM))
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
    }
}
