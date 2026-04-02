import SwiftUI
import SwiftData
import PhotosUI

/// Used for both adding a new baby (existing == nil) and editing an existing one.
struct AddBabySheet: View {

    var existing: Baby? = nil
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncManager.self) private var syncManager

    @State private var name: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var sex: BabySex = .unspecified
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var isDueDate: Bool = false

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoPicker
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Baby's name", text: $name)
                }

                Section("Details") {
                    Picker("Sex", selection: $sex) {
                        ForEach(BabySex.allCases, id: \.self) { Text(sexLabel($0)).tag($0) }
                    }
                    Toggle("Premature / due date instead", isOn: $isDueDate)
                    DatePicker(
                        isDueDate ? "Due date" : "Date of birth",
                        selection: $dateOfBirth,
                        in: isDueDate ? Date()... : ...Date(),
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(isEditing ? "Edit Baby" : "Add Baby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { populateIfEditing() }
        .onChange(of: photoItem) { loadPhoto() }
    }

    // MARK: - Photo picker

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 90, height: 90)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("Photo")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }
            }
            .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 1))
        }
    }

    // MARK: - Save / populate

    private func populateIfEditing() {
        guard let baby = existing else { return }
        name = baby.name
        dateOfBirth = baby.dateOfBirth
        sex = baby.sex
        photoData = baby.photoData
        isDueDate = baby.dueDate != nil
    }

    private func save() {
        if let baby = existing {
            baby.name = name
            baby.dateOfBirth = dateOfBirth
            baby.sex = sex
            baby.photoData = photoData
            baby.dueDate = isDueDate ? dateOfBirth : nil
            baby.updatedAt = Date()
            baby.syncStatus = .pending
        } else {
            let baby = Baby(
                name: name,
                dateOfBirth: dateOfBirth,
                dueDate: isDueDate ? dateOfBirth : nil,
                sex: sex
            )
            baby.photoData = photoData
            modelContext.insert(baby)
            appState.activeBabyID = baby.id

            // Grant admin access to current device caregiver
            if let caregiverID = currentCaregiverID() {
                modelContext.insert(BabyAccess(babyID: baby.id, caregiverID: caregiverID, role: .admin))
            }
        }
        try? modelContext.save()
        onDone()
        dismiss()
    }

    private func loadPhoto() {
        Task {
            if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                await MainActor.run { photoData = data }
            }
        }
    }

    private func currentCaregiverID() -> UUID? {
        let descriptor = FetchDescriptor<Caregiver>(predicate: #Predicate { $0.isCurrentDevice })
        return (try? modelContext.fetch(descriptor))?.first?.id
    }

    private func sexLabel(_ sex: BabySex) -> String {
        switch sex {
        case .male: return "Boy"
        case .female: return "Girl"
        case .unspecified: return "Prefer not to say"
        }
    }
}
