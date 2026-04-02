import SwiftUI
import SwiftData

struct MedicationManagementView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var showAddMedication = false
    @State private var editingMedication: Medication? = nil
    @State private var showStopConfirm = false
    @State private var medicationToStop: Medication? = nil

    @Query private var allMedications: [Medication]

    private var medications: [Medication] {
        allMedications.filter { $0.babyID == baby.id }
                      .sorted { $0.startDate > $1.startDate }
    }

    private var active: [Medication] { medications.filter(\.isActive) }
    private var inactive: [Medication] { medications.filter { !$0.isActive } }

    var body: some View {
        List {
            if active.isEmpty && inactive.isEmpty {
                emptyState
            } else {
                if !active.isEmpty {
                    Section("Active") {
                        ForEach(active) { med in
                            MedicationRow(medication: med) {
                                editingMedication = med
                            } onStop: {
                                medicationToStop = med
                                showStopConfirm = true
                            }
                        }
                    }
                }
                if !inactive.isEmpty {
                    Section("Past") {
                        ForEach(inactive) { med in
                            MedicationRow(medication: med) {
                                editingMedication = med
                            } onStop: nil
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMedication = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationSheet(babyID: baby.id) {}
        }
        .sheet(item: $editingMedication) { med in
            AddMedicationSheet(babyID: baby.id, existing: med) {}
        }
        .confirmationDialog("Stop this medication?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button("Stop Medication", role: .destructive) {
                if let med = medicationToStop {
                    med.isActive = false
                    med.endDate = Date()
                    med.updatedAt = Date()
                    med.syncStatus = .pending
                    try? modelContext.save()
                    syncManager.enqueue(SyncOperation(
                        modelType: "Medication", modelID: med.id, operation: .update, payload: Data()
                    ))
                }
                medicationToStop = nil
            }
            Button("Cancel", role: .cancel) { medicationToStop = nil }
        } message: {
            if let med = medicationToStop {
                Text(""\(med.name)" will be marked as discontinued.")
            }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "pill.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.purple.opacity(0.6))
                Text("No medications yet")
                    .font(.headline)
                Text("Add \(baby.name)'s medications to track doses and set reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Add Medication") { showAddMedication = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Medication Row

private struct MedicationRow: View {
    let medication: Medication
    let onEdit: () -> Void
    let onStop: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((medication.isActive ? Color.purple : Color.gray).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "pill.fill")
                    .foregroundStyle(medication.isActive ? .purple : .gray)
                    .font(.system(size: 15, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(medication.name)
                        .font(.subheadline.weight(.semibold))
                    if !medication.isActive {
                        Text("Stopped")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(doseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let freq = medication.frequencyHours {
                    Text("Every \(Int(freq))h · started \(medication.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("As needed · started \(medication.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onStop {
                Button(role: .destructive, action: onStop) {
                    Label("Stop", systemImage: "stop.circle")
                }
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .onTapGesture { onEdit() }
    }

    private var doseLabel: String {
        "\(medication.dose.formatted()) \(medication.doseUnit.rawValue) · \(medication.route.rawValue)"
    }
}

// MARK: - Add / Edit Medication Sheet

struct AddMedicationSheet: View {

    let babyID: UUID
    var existing: Medication? = nil
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var name: String = ""
    @State private var dose: Double = 5
    @State private var doseUnit: DoseUnit = .ml
    @State private var route: MedRoute = .oral
    @State private var isScheduled: Bool = false
    @State private var frequencyHours: Double = 8
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var showEndDate: Bool = false
    @State private var prescribedBy: String = ""
    @State private var notes: String = ""

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (e.g. Tylenol, Amoxicillin)", text: $name)
                    HStack {
                        Text("Dose")
                        Spacer()
                        TextField("Amount", value: $dose, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    Picker("Route", selection: $route) {
                        ForEach(MedRoute.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Schedule") {
                    Toggle("Scheduled (regular frequency)", isOn: $isScheduled)
                    if isScheduled {
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text("Every")
                            TextField("8", value: $frequencyHours, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 44)
                            Text("hours").foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $showEndDate)
                    if showEndDate {
                        DatePicker("End date", selection: Binding(
                            get: { endDate ?? startDate.addingTimeInterval(86400 * 7) },
                            set: { endDate = $0 }
                        ), in: startDate..., displayedComponents: .date)
                    }
                }

                Section("Prescriber") {
                    TextField("Prescribed by (optional)", text: $prescribedBy)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { populate() }
    }

    private func populate() {
        guard let med = existing else { return }
        name = med.name
        dose = med.dose
        doseUnit = med.doseUnit
        route = med.route
        isScheduled = med.isScheduled
        frequencyHours = med.frequencyHours ?? 8
        startDate = med.startDate
        if let end = med.endDate {
            endDate = end
            showEndDate = true
        }
        prescribedBy = med.prescribedBy ?? ""
        notes = med.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let caregiverID = currentCaregiver?.id ?? UUID()

        if let med = existing {
            med.name = trimmedName
            med.dose = dose
            med.doseUnit = doseUnit
            med.route = route
            med.isScheduled = isScheduled
            med.frequencyHours = isScheduled ? frequencyHours : nil
            med.startDate = startDate
            med.endDate = showEndDate ? endDate : nil
            med.prescribedBy = prescribedBy.isEmpty ? nil : prescribedBy
            med.notes = notes.isEmpty ? nil : notes
            med.updatedAt = Date()
            med.syncStatus = .pending
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Medication", modelID: med.id, operation: .update, payload: Data()
            ))
        } else {
            let med = Medication(
                babyID: babyID,
                createdByID: caregiverID,
                name: trimmedName,
                dose: dose,
                unit: doseUnit,
                route: route
            )
            med.isScheduled = isScheduled
            med.frequencyHours = isScheduled ? frequencyHours : nil
            med.startDate = startDate
            med.endDate = showEndDate ? endDate : nil
            med.prescribedBy = prescribedBy.isEmpty ? nil : prescribedBy
            med.notes = notes.isEmpty ? nil : notes
            modelContext.insert(med)
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Medication", modelID: med.id, operation: .create, payload: Data()
            ))
        }
        HapticManager.success()
        onSave()
        dismiss()
    }
}
