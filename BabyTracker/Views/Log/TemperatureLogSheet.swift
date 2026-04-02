import SwiftUI
import SwiftData

struct TemperatureLogSheet: View {

    let babyID: UUID
    var babyName: String = "Baby"
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var valueFahrenheit: Double = 98.6
    @State private var usefahrenheit: Bool = true
    @State private var method: TempMethod = .axillary
    @State private var timestamp: Date = Date()
    @State private var notes: String = ""

    private var displayValue: Double {
        get { usefahrenheit ? valueFahrenheit : (valueFahrenheit - 32) * 5 / 9 }
    }

    private var isFever: Bool { valueFahrenheit >= 100.4 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Big temperature display
                    VStack(spacing: 16) {
                        Text(String(format: "%.1f°%@", displayValue, usefahrenheit ? "F" : "C"))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(isFever ? .red : .primary)
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)

                        if isFever {
                            Label("Fever detected (\(String(format: "%.1f", valueFahrenheit))°F / \(String(format: "%.1f", (valueFahrenheit - 32) * 5 / 9))°C)",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .onAppear { HapticManager.warning() }
                        }

                        // Slider: 96–106°F
                        VStack(spacing: 4) {
                            Slider(value: $valueFahrenheit, in: 96...106, step: 0.1)
                                .tint(isFever ? .red : .accentColor)
                            HStack {
                                Text(usefahrenheit ? "96°F" : "35.6°C").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text(usefahrenheit ? "106°F" : "41.1°C").font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        // Unit toggle
                        Picker("Unit", selection: $usefahrenheit) {
                            Text("°F").tag(true)
                            Text("°C").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Method") {
                    Picker("Measurement method", selection: $method) {
                        ForEach(TempMethod.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Time") {
                    DatePicker("Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Log Temperature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let entry = TemperatureEntry(
            babyID: babyID,
            caregiverID: currentCaregiver?.id ?? UUID(),
            valueFahrenheit: valueFahrenheit,
            method: method,
            timestamp: timestamp
        )
        entry.notes = notes.isEmpty ? nil : notes
        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()
        onSave()
        dismiss()
    }
}
