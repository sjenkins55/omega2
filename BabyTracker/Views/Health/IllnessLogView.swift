import SwiftUI
import SwiftData

struct IllnessLogView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @Query private var allIllnesses: [Illness]

    private var illnesses: [Illness] {
        allIllnesses.filter { $0.babyID == baby.id }
                    .sorted { $0.onsetDate > $1.onsetDate }
    }

    @State private var showAddIllness = false
    @State private var editingIllness: Illness? = nil
    @State private var showResolveConfirm = false
    @State private var illnessToResolve: Illness? = nil

    var body: some View {
        List {
            if illnesses.isEmpty {
                emptyState
            } else {
                let current = illnesses.filter(\.isActive)
                let past = illnesses.filter { !$0.isActive }

                if !current.isEmpty {
                    Section("Active") {
                        ForEach(current) { illness in
                            IllnessRow(illness: illness)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        illnessToResolve = illness
                                        showResolveConfirm = true
                                    } label: {
                                        Label("Resolved", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                    Button {
                                        editingIllness = illness
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                if !past.isEmpty {
                    Section("Past") {
                        ForEach(past) { illness in
                            IllnessRow(illness: illness)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editingIllness = illness
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Illness Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddIllness = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddIllness) {
            AddIllnessSheet(babyID: baby.id, babyName: baby.name) {}
        }
        .sheet(item: $editingIllness) { illness in
            AddIllnessSheet(babyID: baby.id, babyName: baby.name, existing: illness) {}
        }
        .confirmationDialog("Mark as resolved?", isPresented: $showResolveConfirm, titleVisibility: .visible) {
            Button("Mark Resolved") {
                if let illness = illnessToResolve {
                    illness.endDate = Date()
                    illness.updatedAt = Date()
                    illness.syncStatus = .pending
                    try? modelContext.save()
                    syncManager.enqueue(SyncOperation(
                        modelType: "Illness", modelID: illness.id, operation: .update, payload: Data()
                    ))
                }
                illnessToResolve = nil
            }
            Button("Cancel", role: .cancel) { illnessToResolve = nil }
        } message: {
            Text("Today will be set as the end date.")
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange.opacity(0.7))
                Text("No illnesses logged")
                    .font(.headline)
                Text("Track symptoms, onset dates, and recovery for \(baby.name).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Log Illness") { showAddIllness = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Illness Row

private struct IllnessRow: View {
    let illness: Illness

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((illness.isActive ? Color.orange : Color.gray).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(illness.isActive ? .orange : .gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(illness.isActive ? "Active illness" : "Recovered")
                        .font(.subheadline.weight(.semibold))
                    if illness.isActive {
                        Text("Active")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                if !illness.symptoms.isEmpty {
                    Text(illness.symptoms.map(\.rawValue).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(dateRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var dateRangeLabel: String {
        let onset = illness.onsetDate.formatted(date: .abbreviated, time: .omitted)
        if let end = illness.endDate {
            let days = Calendar.current.dateComponents([.day], from: illness.onsetDate, to: end).day ?? 0
            return "Onset \(onset) · \(days + 1) day\(days == 0 ? "" : "s")"
        }
        let days = Calendar.current.dateComponents([.day], from: illness.onsetDate, to: Date()).day ?? 0
        return "Onset \(onset) · Day \(days + 1)"
    }
}

// MARK: - Add / Edit Illness Sheet

struct AddIllnessSheet: View {

    let babyID: UUID
    let babyName: String
    var existing: Illness? = nil
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var onsetDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var notes: String = ""

    var isEditing: Bool { existing != nil }

    private let symptomColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker("Onset date", selection: $onsetDate, in: ...Date(), displayedComponents: .date)
                    Toggle("Resolved", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: onsetDate..., displayedComponents: .date)
                    }
                }

                Section {
                    LazyVGrid(columns: symptomColumns, spacing: 8) {
                        ForEach(Symptom.allCases, id: \.self) { symptom in
                            SymptomToggle(
                                symptom: symptom,
                                isSelected: selectedSymptoms.contains(symptom)
                            ) {
                                if selectedSymptoms.contains(symptom) {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Symptoms")
                } footer: {
                    if selectedSymptoms.isEmpty {
                        Text("Tap symptoms to select. At least one is recommended.")
                    }
                }

                Section("Notes") {
                    TextField("Notes (doctor visit, treatment, etc.)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? "Edit Illness" : "Log Illness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { populate() }
    }

    private func populate() {
        guard let illness = existing else { return }
        onsetDate = illness.onsetDate
        if let end = illness.endDate {
            hasEndDate = true
            endDate = end
        }
        selectedSymptoms = Set(illness.symptoms)
        notes = illness.notes ?? ""
    }

    private func save() {
        let caregiverID = currentCaregiver?.id ?? UUID()

        if let illness = existing {
            illness.onsetDate = onsetDate
            illness.endDate = hasEndDate ? endDate : nil
            illness.symptoms = Array(selectedSymptoms)
            illness.notes = notes.isEmpty ? nil : notes
            illness.updatedAt = Date()
            illness.syncStatus = .pending
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Illness", modelID: illness.id, operation: .update, payload: Data()
            ))
        } else {
            let illness = Illness(babyID: babyID, caregiverID: caregiverID, onsetDate: onsetDate)
            illness.endDate = hasEndDate ? endDate : nil
            illness.symptoms = Array(selectedSymptoms)
            illness.notes = notes.isEmpty ? nil : notes
            modelContext.insert(illness)
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Illness", modelID: illness.id, operation: .create, payload: Data()
            ))
        }
        HapticManager.success()
        onSave()
        dismiss()
    }
}

// MARK: - Symptom Toggle Chip

private struct SymptomToggle: View {
    let symptom: Symptom
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .font(.system(size: 13))
                Text(symptom.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
