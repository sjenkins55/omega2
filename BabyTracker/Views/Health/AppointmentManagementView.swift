import SwiftUI
import SwiftData

struct AppointmentManagementView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @Query private var allAppointments: [Appointment]

    private var appointments: [Appointment] {
        allAppointments.filter { $0.babyID == babyID }
                       .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private var upcoming: [Appointment] { appointments.filter { $0.scheduledAt >= Date() } }
    private var past: [Appointment] { appointments.filter { $0.scheduledAt < Date() } }

    @State private var showAdd = false
    @State private var editing: Appointment? = nil
    @State private var deleteTarget: Appointment? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            if appointments.isEmpty {
                emptyState
            } else {
                if !upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcoming.reversed()) { appt in
                            AppointmentRow(appointment: appt)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    deleteButton(appt)
                                    editButton(appt)
                                }
                        }
                    }
                }
                if !past.isEmpty {
                    Section("Past") {
                        ForEach(past) { appt in
                            AppointmentRow(appointment: appt)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    deleteButton(appt)
                                    editButton(appt)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Appointments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAppointmentSheet(babyID: baby.id, babyName: baby.name) {}
        }
        .sheet(item: $editing) { appt in
            AddAppointmentSheet(babyID: baby.id, babyName: baby.name, existing: appt) {}
        }
        .confirmationDialog("Delete appointment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let appt = deleteTarget { delete(appt) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Swipe buttons

    @ViewBuilder
    private func deleteButton(_ appt: Appointment) -> some View {
        Button(role: .destructive) {
            deleteTarget = appt
            showDeleteConfirm = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func editButton(_ appt: Appointment) -> some View {
        Button { editing = appt } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }

    private func delete(_ appt: Appointment) {
        NotificationService.shared.cancelAppointmentReminders(appointmentID: appt.id)
        appt.syncStatus = .deleted
        syncManager.enqueue(SyncOperation(
            modelType: "Appointment", modelID: appt.id, operation: .delete, payload: Data()
        ))
        modelContext.delete(appt)
        try? modelContext.save()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.opacity(0.7))
                Text("No appointments yet")
                    .font(.headline)
                Text("Schedule well-visits, specialist appointments, and sick visits for \(babyName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Add Appointment") { showAdd = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Appointment Row

private struct AppointmentRow: View {
    let appointment: Appointment

    private var isUpcoming: Bool { appointment.scheduledAt >= Date() }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((isUpcoming ? Color.blue : Color.gray).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: typeIcon)
                    .foregroundStyle(isUpcoming ? .blue : .gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(appointment.appointmentType.rawValue)
                        .font(.subheadline.weight(.semibold))
                    if isUpcoming {
                        Text(daysUntilLabel)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                if let provider = appointment.provider, !provider.isEmpty {
                    Text(provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private var typeIcon: String {
        switch appointment.appointmentType {
        case .wellVisit:   return "heart.text.square.fill"
        case .sick:        return "thermometer.medium"
        case .specialist:  return "stethoscope"
        case .other:       return "calendar"
        }
    }

    private var daysUntilLabel: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: appointment.scheduledAt).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }
}

// MARK: - Add / Edit Appointment Sheet

struct AddAppointmentSheet: View {

    let babyID: UUID
    let babyName: String
    var existing: Appointment? = nil
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var scheduledAt: Date = Calendar.current.date(
        byAdding: .day, value: 7, to: Date()
    ) ?? Date()
    @State private var type: AppointmentType = .wellVisit
    @State private var provider: String = ""
    @State private var notes: String = ""
    @State private var scheduleReminder: Bool = true

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appointment") {
                    Picker("Type", selection: $type) {
                        ForEach(AppointmentType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("Date & Time", selection: $scheduledAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    TextField("Provider / Doctor (optional)", text: $provider)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Toggle("Set reminder", isOn: $scheduleReminder)
                } footer: {
                    if scheduleReminder {
                        Text("You'll be notified 1 day before and the morning of the appointment.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Appointment" : "Add Appointment")
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
        .presentationDetents([.medium, .large])
        .onAppear { populate() }
    }

    private func populate() {
        guard let appt = existing else { return }
        scheduledAt = appt.scheduledAt
        type = appt.appointmentType
        provider = appt.provider ?? ""
        notes = appt.notes ?? ""
    }

    private func save() {
        let caregiverID = currentCaregiver?.id ?? UUID()

        if let appt = existing {
            NotificationService.shared.cancelAppointmentReminders(appointmentID: appt.id)
            appt.scheduledAt = scheduledAt
            appt.appointmentType = type
            appt.provider = provider.isEmpty ? nil : provider
            appt.notes = notes.isEmpty ? nil : notes
            appt.updatedAt = Date()
            appt.syncStatus = .pending
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Appointment", modelID: appt.id, operation: .update, payload: Data()
            ))
            if scheduleReminder {
                Task {
                    await NotificationService.shared.scheduleAppointmentReminder(
                        appointmentID: appt.id,
                        type: type.rawValue,
                        babyName: babyName,
                        scheduledAt: scheduledAt
                    )
                }
            }
        } else {
            let appt = Appointment(babyID: babyID, caregiverID: caregiverID, scheduledAt: scheduledAt, type: type)
            appt.provider = provider.isEmpty ? nil : provider
            appt.notes = notes.isEmpty ? nil : notes
            modelContext.insert(appt)
            try? modelContext.save()
            syncManager.enqueue(SyncOperation(
                modelType: "Appointment", modelID: appt.id, operation: .insert, payload: Data()
            ))
            if scheduleReminder {
                Task {
                    await NotificationService.shared.scheduleAppointmentReminder(
                        appointmentID: appt.id,
                        type: type.rawValue,
                        babyName: babyName,
                        scheduledAt: scheduledAt
                    )
                }
            }
        }
        HapticManager.success()
        onSave()
        dismiss()
    }
}
