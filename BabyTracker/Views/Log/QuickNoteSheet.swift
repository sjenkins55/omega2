import SwiftUI
import SwiftData

/// Freeform note attached to a HandoffNote — visible to all caregivers on this baby.
struct QuickNoteSheet: View {

    let babyID: UUID
    var babyName: String = "Baby"
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentCaregiver) private var currentCaregiver

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Existing handoff note preview
                if let existing = existingNote() {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Current handoff note", systemImage: "note.text")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(existing.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    Divider()
                }

                TextEditor(text: $text)
                    .focused($focused)
                    .font(.body)
                    .padding()
                    .frame(maxHeight: .infinity)

                Text("\(text.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Handoff Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }

    private func existingNote() -> HandoffNote? {
        let descriptor = FetchDescriptor<HandoffNote>(
            predicate: #Predicate { $0.babyID == babyID && $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func save() {
        // Deactivate any current note
        if let current = existingNote() {
            current.isActive = false
        }
        let note = HandoffNote(
            babyID: babyID,
            authorCaregiverID: currentCaregiver?.id ?? UUID(),
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(note)
        try? modelContext.save()
        HapticManager.success()
        onSave()
        dismiss()
    }
}
