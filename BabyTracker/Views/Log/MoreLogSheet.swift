import SwiftUI

/// "More" quick-log panel — accessed from the FAB's "Other" action.
/// Lets caregivers quickly log Temperature, Medication dose, and freeform Notes
/// without navigating to the health section.
struct MoreLogSheet: View {

    let babyID: UUID
    var babyName: String = "Baby"
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var activeEntry: MoreEntry? = nil

    enum MoreEntry: Identifiable {
        case temperature, medicationDose, note
        var id: String { "\(self)" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MoreRow(icon: "thermometer.medium", color: .red,
                            title: "Temperature",
                            subtitle: "Log a temp reading") {
                        activeEntry = .temperature
                    }
                    MoreRow(icon: "pill.fill", color: .purple,
                            title: "Medication Dose",
                            subtitle: "Mark a dose as given") {
                        activeEntry = .medicationDose
                    }
                    MoreRow(icon: "note.text", color: .gray,
                            title: "Quick Note",
                            subtitle: "Freeform text note") {
                        activeEntry = .note
                    }
                } header: {
                    Text("Log for \(babyName)")
                }

                Section {
                    NavigationLink {
                        Text("Illness log — open from Health section in Profile")
                            .foregroundStyle(.secondary)
                            .padding()
                    } label: {
                        MoreRow(icon: "cross.case.fill", color: .orange,
                                title: "Illness",
                                subtitle: "Track symptoms and duration") {}
                    }
                    NavigationLink {
                        Text("Appointments — open from Health section in Profile")
                            .foregroundStyle(.secondary)
                            .padding()
                    } label: {
                        MoreRow(icon: "calendar.badge.plus", color: .blue,
                                title: "Appointment",
                                subtitle: "Schedule or log a visit") {}
                    }
                } header: {
                    Text("Health")
                } footer: {
                    Text("Full health tracking is available in the Profile → Health & Growth section.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $activeEntry) { entry in
            switch entry {
            case .temperature:
                TemperatureLogSheet(babyID: babyID, babyName: babyName) {
                    onSave()
                    activeEntry = nil
                }
            case .medicationDose:
                MedicationDoseSheet(babyID: babyID, babyName: babyName) {
                    onSave()
                    activeEntry = nil
                }
            case .note:
                QuickNoteSheet(babyID: babyID, babyName: babyName) {
                    onSave()
                    activeEntry = nil
                }
            }
        }
    }
}

private struct MoreRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 15, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
