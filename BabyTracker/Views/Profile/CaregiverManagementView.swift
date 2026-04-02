import SwiftUI
import SwiftData

struct CaregiverManagementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var auth
    @Environment(SyncManager.self) private var syncManager

    @Query private var allAccesses: [BabyAccess]
    @Query private var allCaregivers: [Caregiver]

    @State private var showInvite = false
    @State private var confirmRemoveID: UUID? = nil
    @State private var confirmRoleChange: (UUID, CaregiverRole)? = nil

    private var babyID: UUID? { appState.activeBabyID }

    private var accesses: [BabyAccess] {
        guard let bid = babyID else { return [] }
        return allAccesses.filter { $0.babyID == bid }
    }

    private func caregiver(for access: BabyAccess) -> Caregiver? {
        allCaregivers.first { $0.id == access.caregiverID }
    }

    private var isAdmin: Bool {
        auth.currentCaregiver?.role == .admin
    }

    var body: some View {
        List {
            Section {
                ForEach(accesses) { access in
                    if let cg = caregiver(for: access) {
                        caregiverRow(cg, access: access)
                    }
                }
            } header: {
                Text("Current Caregivers")
            } footer: {
                Text("Caregivers can log entries. Viewers can only view. Only admins can manage caregivers or delete entries.")
                    .font(.caption)
            }

            if isAdmin {
                Section {
                    Button {
                        showInvite = true
                    } label: {
                        Label("Invite a Caregiver", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .navigationTitle("Caregivers")
        .sheet(isPresented: $showInvite) {
            if let bid = babyID {
                InviteView(babyID: bid)
            }
        }
        .confirmationDialog(
            "Remove this caregiver?",
            isPresented: Binding(get: { confirmRemoveID != nil }, set: { if !$0 { confirmRemoveID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { removeCaregiver() }
            Button("Cancel", role: .cancel) { confirmRemoveID = nil }
        } message: {
            Text("They will lose access to this baby's data.")
        }
    }

    // MARK: - Caregiver row

    private func caregiverRow(_ caregiver: Caregiver, access: BabyAccess) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor(caregiver.displayName))
                    .frame(width: 42, height: 42)
                Text(caregiver.displayName.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(caregiver.displayName)
                        .font(.subheadline.weight(.semibold))
                    if caregiver.isCurrentDevice {
                        Text("You")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
                Text(access.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAdmin && !caregiver.isCurrentDevice {
                Menu {
                    // Role change
                    Menu("Change Role") {
                        ForEach([CaregiverRole.admin, .caregiver, .viewer], id: \.self) { role in
                            Button {
                                changeRole(accessID: access.id, to: role)
                            } label: {
                                if access.role == role {
                                    Label(role.displayName, systemImage: "checkmark")
                                } else {
                                    Text(role.displayName)
                                }
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmRemoveID = caregiver.id
                    } label: {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func changeRole(accessID: UUID, to role: CaregiverRole) {
        guard let access = allAccesses.first(where: { $0.id == accessID }) else { return }
        access.role = role
        access.syncStatus = .pending
        try? modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "BabyAccess",
            modelID: access.id,
            operation: .update,
            payload: Data()
        ))
    }

    private func removeCaregiver() {
        guard let cid = confirmRemoveID, let bid = babyID else { return }
        let toRemove = allAccesses.filter { $0.babyID == bid && $0.caregiverID == cid }
        for access in toRemove {
            access.syncStatus = .deleted
            syncManager.enqueue(SyncOperation(
                modelType: "BabyAccess", modelID: access.id, operation: .delete, payload: Data()
            ))
            modelContext.delete(access)
        }
        try? modelContext.save()
        confirmRemoveID = nil
    }

    private func avatarColor(_ name: String) -> Color {
        let colors: [Color] = [.pink, .purple, .indigo, .blue, .teal, .green, .orange]
        return colors[abs(name.hashValue) % colors.count]
    }
}
