import SwiftUI
import SwiftData

struct DiaperLogSheet: View {

    let babyID: UUID
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var diaperType: DiaperType = .wet
    @State private var stoolColor: StoolColor? = nil
    @State private var stoolConsistency: StoolConsistency? = nil
    @State private var entryTime: Date = Date()
    @State private var notes: String = ""

    private let showStoolDetails: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                if diaperType == .dirty || diaperType == .both {
                    stoolSection
                }
                timeSection
                notesSection
            }
            .navigationTitle("Log Diaper")
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
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("Type") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DiaperType.allCases, id: \.self) { type in
                    DiaperTypeTile(type: type, isSelected: diaperType == type) {
                        withAnimation(.spring(response: 0.25)) {
                            diaperType = type
                            // Clear stool details if switching away from dirty
                            if type == .wet || type == .dry {
                                stoolColor = nil
                                stoolConsistency = nil
                            }
                        }
                    }
                }
            }
            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
    }

    private var stoolSection: some View {
        Section {
            // Color picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(StoolColor.allCases, id: \.self) { color in
                        StoolColorSwatch(color: color, isSelected: stoolColor == color) {
                            stoolColor = stoolColor == color ? nil : color
                            if [StoolColor.red, .black, .white].contains(color) {
                                HapticManager.warning()
                            } else {
                                HapticManager.light()
                            }
                        }
                    }
                }

                if let color = stoolColor, isAlarmColor(color) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(alarmMessage(for: color))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(8)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // Consistency picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Consistency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StoolConsistency.allCases, id: \.self) { c in
                            Button {
                                stoolConsistency = stoolConsistency == c ? nil : c
                            } label: {
                                Text(c.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(stoolConsistency == c ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundStyle(stoolConsistency == c ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        } header: {
            Text("Stool Details")
        }
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Time", selection: $entryTime, displayedComponents: [.date, .hourAndMinute])
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Save

    private func save() {
        let caregiverID = UUID()
        let entry = DiaperEntry(babyID: babyID, caregiverID: caregiverID, diaperType: diaperType, timestamp: entryTime)
        entry.stoolColor = stoolColor
        entry.stoolConsistency = stoolConsistency
        entry.notes = notes.isEmpty ? nil : notes

        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()

        // Reschedule diaper reminder (default 3-hour interval)
        Task {
            await NotificationService.shared.scheduleDiaperReminder(
                babyID: babyID,
                babyName: "Baby",
                lastChangeAt: entryTime,
                intervalMinutes: 180
            )
        }

        onSave()
        dismiss()
    }

    // MARK: - Alarm helpers

    private func isAlarmColor(_ color: StoolColor) -> Bool {
        color == .red || color == .black || color == .white
    }

    private func alarmMessage(for color: StoolColor) -> String {
        switch color {
        case .red:   return "Red may indicate blood. Contact your pediatrician."
        case .black: return "Black (non-meconium) may indicate bleeding. Contact your pediatrician."
        case .white: return "White or gray may indicate a bile duct issue. Seek medical advice."
        default:     return ""
        }
    }
}

// MARK: - Diaper Type Tile

struct DiaperTypeTile: View {
    let type: DiaperType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : tileColor)
                Text(type.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tileColor : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch type {
        case .wet:   return "drop.fill"
        case .dirty: return "drop.triangle.fill"
        case .both:  return "drop.degreesign.fill"
        case .dry:   return "circle.slash"
        }
    }

    private var tileColor: Color {
        switch type {
        case .wet:   return .blue
        case .dirty: return .orange
        case .both:  return .brown
        case .dry:   return .gray
        }
    }
}

// MARK: - Stool Color Swatch

struct StoolColorSwatch: View {
    let color: StoolColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Circle()
                    .fill(swatchColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                            .padding(-3)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                Text(color.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var swatchColor: Color {
        switch color {
        case .yellow:  return Color(red: 1.0, green: 0.85, blue: 0.2)
        case .mustard: return Color(red: 0.8, green: 0.65, blue: 0.1)
        case .brown:   return Color(red: 0.5, green: 0.3, blue: 0.1)
        case .green:   return Color(red: 0.3, green: 0.65, blue: 0.3)
        case .orange:  return Color(red: 1.0, green: 0.55, blue: 0.1)
        case .red:     return Color.red
        case .black:   return Color(white: 0.15)
        case .white:   return Color(white: 0.88)
        }
    }
}
