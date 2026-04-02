import SwiftUI
import SwiftData

struct VaccineScheduleView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Query private var allVaccines: [VaccineEntry]
    @State private var showAddVaccine = false
    @State private var expandedBand: String? = nil

    private var adminedKeys: Set<String> {
        Set(allVaccines.filter { $0.babyID == baby.id }.compactMap(\.vaccineKey))
    }

    var body: some View {
        List {
            // Upcoming callout
            let upcoming = upcomingDoses
            if !upcoming.isEmpty {
                Section {
                    upcomingBanner(upcoming)
                        .listRowBackground(Color.orange.opacity(0.08))
                        .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }

            // Schedule by age band
            ForEach(VaccineDefinition.byAgeBand, id: \.label) { band in
                let completed = bandCompletionCount(band)
                let total = band.vaccines.count

                Section {
                    if expandedBand == band.label {
                        ForEach(band.vaccines, id: \.vaccine.id) { item in
                            VaccineDoseRow(
                                vaccine: item.vaccine,
                                doseNumber: item.doseNumber,
                                isCompleted: isDoseCompleted(vaccine: item.vaccine, dose: item.doseNumber),
                                onToggle: { toggleDose(vaccine: item.vaccine, dose: item.doseNumber, ageMonths: band.months) }
                            )
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            expandedBand = expandedBand == band.label ? nil : band.label
                        }
                    } label: {
                        HStack {
                            Text(band.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            // Progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color(.systemFill), lineWidth: 3)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .trim(from: 0, to: total > 0 ? CGFloat(completed) / CGFloat(total) : 0)
                                    .stroke(completed == total ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 24, height: 24)
                                    .rotationEffect(.degrees(-90))
                            }
                            Text("\(completed)/\(total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: expandedBand == band.label ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
                }
            }

            // Administered doses log
            if !allVaccines.filter({ $0.babyID == baby.id }).isEmpty {
                Section("Administered") {
                    ForEach(allVaccines.filter { $0.babyID == baby.id }.sorted { $0.administeredAt > $1.administeredAt }) { entry in
                        VaccineLogRow(entry: entry)
                    }
                    .onDelete { offsets in
                        let entries = allVaccines.filter { $0.babyID == baby.id }.sorted { $0.administeredAt > $1.administeredAt }
                        for i in offsets { modelContext.delete(entries[i]) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Vaccines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddVaccine = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddVaccine) {
            AddVaccineSheet(baby: baby)
        }
        .onAppear {
            // Auto-expand the age band matching baby's current age
            let ageMonths = baby.ageInMonths
            let band = VaccineDefinition.byAgeBand.first { $0.months <= ageMonths + 1 && !isBandComplete($0) }
            expandedBand = band?.label ?? VaccineDefinition.byAgeBand.first?.label
        }
    }

    // MARK: - Upcoming banner

    private func upcomingBanner(_ doses: [(vaccine: VaccineDefinition, bandLabel: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Upcoming Vaccines", systemImage: "calendar.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(doses.prefix(3), id: \.vaccine.id) { item in
                HStack {
                    Text("• \(item.vaccine.abbreviation)")
                        .font(.caption.weight(.medium))
                    Text("— \(item.bandLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if doses.count > 3 {
                Text("and \(doses.count - 3) more…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }

    // MARK: - Helpers

    private func isDoseCompleted(vaccine: VaccineDefinition, dose: Int) -> Bool {
        let key = "\(vaccine.id)-dose\(dose)"
        return adminedKeys.contains(key) || adminedKeys.contains(vaccine.id)
    }

    private func toggleDose(vaccine: VaccineDefinition, dose: Int, ageMonths: Int) {
        let key = "\(vaccine.id)-dose\(dose)"
        if isDoseCompleted(vaccine: vaccine, dose: dose) {
            // Remove the entry
            if let existing = allVaccines.first(where: { $0.babyID == baby.id && $0.vaccineKey == key }) {
                modelContext.delete(existing)
                try? modelContext.save()
            }
        } else {
            // Add entry
            let entry = VaccineEntry(babyID: baby.id, caregiverID: UUID(), vaccineKey: key)
            entry.administeredAt = Date()
            modelContext.insert(entry)
            try? modelContext.save()
        }
    }

    private func bandCompletionCount(_ band: (label: String, months: Int, vaccines: [(vaccine: VaccineDefinition, doseNumber: Int)])) -> Int {
        band.vaccines.filter { isDoseCompleted(vaccine: $0.vaccine, dose: $0.doseNumber) }.count
    }

    private func isBandComplete(_ band: (label: String, months: Int, vaccines: [(vaccine: VaccineDefinition, doseNumber: Int)])) -> Bool {
        bandCompletionCount(band) == band.vaccines.count
    }

    private var upcomingDoses: [(vaccine: VaccineDefinition, bandLabel: String)] {
        let ageMonths = baby.ageInMonths
        var result: [(VaccineDefinition, String)] = []
        for band in VaccineDefinition.byAgeBand {
            guard band.months > ageMonths && band.months <= ageMonths + 2 else { continue }
            for item in band.vaccines where !isDoseCompleted(vaccine: item.vaccine, dose: item.doseNumber) {
                result.append((item.vaccine, band.label))
            }
        }
        return result
    }
}

// MARK: - Vaccine Dose Row

struct VaccineDoseRow: View {
    let vaccine: VaccineDefinition
    let doseNumber: Int
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vaccine.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .strikethrough(isCompleted)
                    Text("Dose \(doseNumber) · \(vaccine.abbreviation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vaccine Log Row

struct VaccineLogRow: View {
    let entry: VaccineEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.medium))
                Text(entry.administeredAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let provider = entry.provider {
                Text(provider)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Vaccine Sheet

struct AddVaccineSheet: View {

    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedVaccineID: String = VaccineDefinition.all.first?.id ?? ""
    @State private var isCustom = false
    @State private var customName = ""
    @State private var administeredAt = Date()
    @State private var provider = ""
    @State private var lotNumber = ""
    @State private var reactions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Custom vaccine", isOn: $isCustom)
                    if isCustom {
                        TextField("Vaccine name", text: $customName)
                    } else {
                        Picker("Vaccine", selection: $selectedVaccineID) {
                            ForEach(VaccineDefinition.all) { v in
                                Text("\(v.name) (\(v.abbreviation))").tag(v.id)
                            }
                        }
                    }
                }
                Section("Details") {
                    DatePicker("Date given", selection: $administeredAt, displayedComponents: .date)
                    TextField("Provider / clinic", text: $provider)
                    TextField("Lot number", text: $lotNumber)
                }
                Section("Reactions (if any)") {
                    TextField("Describe any reactions", text: $reactions, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Log Vaccine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isCustom && customName.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let entry = VaccineEntry(
            babyID: baby.id, caregiverID: UUID(),
            vaccineKey: isCustom ? nil : selectedVaccineID
        )
        entry.customName = isCustom ? customName : nil
        entry.administeredAt = administeredAt
        entry.provider = provider.isEmpty ? nil : provider
        entry.lotNumber = lotNumber.isEmpty ? nil : lotNumber
        entry.reactions = reactions.isEmpty ? nil : reactions
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
