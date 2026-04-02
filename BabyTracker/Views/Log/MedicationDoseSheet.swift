import SwiftUI
import SwiftData

/// Quick-log a dose for an existing medication.
/// Accessed from the "More" quick-log panel.
struct MedicationDoseSheet: View {

    let babyID: UUID
    var babyName: String = "Baby"
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentCaregiver) private var currentCaregiver

    @Query private var allMedications: [Medication]

    @State private var selectedMedicationID: UUID? = nil
    @State private var skipped: Bool = false
    @State private var administeredAt: Date = Date()
    @State private var notes: String = ""

    private var activeMedications: [Medication] {
        allMedications.filter { $0.babyID == babyID && $0.isActive }
            .sorted { $0.name < $1.name }
    }

    private var selectedMed: Medication? {
        activeMedications.first { $0.id == selectedMedicationID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if activeMedications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No active medications",
                            systemImage: "pill.fill",
                            description: Text("Add a medication in Profile → Health & Growth first.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Medication") {
                        ForEach(activeMedications) { med in
                            Button {
                                selectedMedicationID = med.id
                                HapticManager.light()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(med.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                        Text("\(med.dose, specifier: "%.1f") \(med.doseUnit.rawValue) · \(med.route.rawValue)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedMedicationID == med.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedMed != nil {
                        Section {
                            Toggle("Mark as skipped", isOn: $skipped).tint(.orange)
                            DatePicker("Time", selection: $administeredAt, displayedComponents: [.date, .hourAndMinute])
                        }

                        if let med = selectedMed {
                            Section("Dose") {
                                HStack {
                                    Image(systemName: "pill.fill").foregroundStyle(.purple)
                                    Text("\(med.dose, specifier: "%.1f") \(med.doseUnit.rawValue)")
                                        .font(.subheadline.weight(.semibold))
                                    Text("· \(med.route.rawValue)").foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section("Notes") {
                            TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...3)
                        }
                    }
                }
            }
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedMedicationID == nil)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            // Auto-select if only one medication
            if activeMedications.count == 1 { selectedMedicationID = activeMedications[0].id }
        }
    }

    private func save() {
        guard let medID = selectedMedicationID else { return }
        let dose = MedicationDose(
            medicationID: medID,
            caregiverID: currentCaregiver?.id ?? UUID(),
            administeredAt: administeredAt,
            skipped: skipped
        )
        dose.notes = notes.isEmpty ? nil : notes
        modelContext.insert(dose)
        try? modelContext.save()
        HapticManager.success()
        onSave()
        dismiss()
    }
}
