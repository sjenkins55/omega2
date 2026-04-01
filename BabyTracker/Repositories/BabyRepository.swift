import Foundation
import SwiftData

@MainActor
final class BabyRepository {

    private let modelContext: ModelContext
    private let syncManager: SyncManager
    private let currentCaregiver: Caregiver

    init(modelContext: ModelContext, syncManager: SyncManager, currentCaregiver: Caregiver) {
        self.modelContext = modelContext
        self.syncManager = syncManager
        self.currentCaregiver = currentCaregiver
    }

    // MARK: - Babies

    func allBabies() throws -> [Baby] {
        let descriptor = FetchDescriptor<Baby>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.dateOfBirth)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createBaby(_ baby: Baby) throws {
        guard currentCaregiver.role.canManageBabies else {
            throw RepositoryError.insufficientPermissions
        }
        baby.syncStatus = .pending
        modelContext.insert(baby)

        // Automatically create a BabyAccess record for the creator
        let access = BabyAccess(babyID: baby.id, caregiverID: currentCaregiver.id, role: .admin)
        modelContext.insert(access)

        try modelContext.save()

        syncManager.enqueue(SyncOperation(
            modelType: "Baby",
            modelID: baby.id,
            operation: .insert,
            payload: (try? JSONEncoder().encode(BabyPayload(baby))) ?? Data()
        ))
        syncManager.enqueue(SyncOperation(
            modelType: "BabyAccess",
            modelID: access.id,
            operation: .insert,
            payload: (try? JSONEncoder().encode(BabyAccessPayload(access))) ?? Data()
        ))
    }

    func updateBaby(_ baby: Baby) throws {
        guard currentCaregiver.role.canManageBabies else {
            throw RepositoryError.insufficientPermissions
        }
        baby.updatedAt = Date()
        baby.syncStatus = .pending
        try modelContext.save()

        syncManager.enqueue(SyncOperation(
            modelType: "Baby",
            modelID: baby.id,
            operation: .update,
            payload: (try? JSONEncoder().encode(BabyPayload(baby))) ?? Data()
        ))
    }

    func archiveBaby(_ baby: Baby) throws {
        guard currentCaregiver.role.canManageBabies else {
            throw RepositoryError.insufficientPermissions
        }
        baby.isArchived = true
        baby.updatedAt = Date()
        baby.syncStatus = .pending
        try modelContext.save()

        syncManager.enqueue(SyncOperation(
            modelType: "Baby",
            modelID: baby.id,
            operation: .update,
            payload: (try? JSONEncoder().encode(BabyPayload(baby))) ?? Data()
        ))
    }

    // MARK: - Caregivers

    func allCaregivers(for babyID: UUID) throws -> [Caregiver] {
        let accesses = try modelContext.fetch(FetchDescriptor<BabyAccess>(
            predicate: #Predicate { $0.babyID == babyID }
        ))
        let caregiverIDs = accesses.map(\.caregiverID)
        let descriptor = FetchDescriptor<Caregiver>(
            predicate: #Predicate { caregiverIDs.contains($0.id) },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createInvite(babyID: UUID, role: CaregiverRole) throws -> CaregiverInvite {
        guard currentCaregiver.role.canManageCaregivers else {
            throw RepositoryError.insufficientPermissions
        }
        let invite = CaregiverInvite(babyID: babyID, createdByID: currentCaregiver.id, role: role)
        modelContext.insert(invite)
        try modelContext.save()

        syncManager.enqueue(SyncOperation(
            modelType: "CaregiverInvite",
            modelID: invite.id,
            operation: .insert,
            payload: (try? JSONEncoder().encode(InvitePayload(invite))) ?? Data()
        ))
        return invite
    }

    func removeCaregiverAccess(caregiverID: UUID, babyID: UUID) throws {
        guard currentCaregiver.role.canManageCaregivers else {
            throw RepositoryError.insufficientPermissions
        }
        guard caregiverID != currentCaregiver.id else {
            throw RepositoryError.cannotRemoveSelf
        }
        let accesses = try modelContext.fetch(FetchDescriptor<BabyAccess>(
            predicate: #Predicate { $0.babyID == babyID && $0.caregiverID == caregiverID }
        ))
        for access in accesses {
            access.syncStatus = .deleted
            syncManager.enqueue(SyncOperation(
                modelType: "BabyAccess",
                modelID: access.id,
                operation: .delete,
                payload: Data()
            ))
            modelContext.delete(access)
        }
        try modelContext.save()
    }

    // MARK: - Handoff Note

    func activeHandoffNote(for babyID: UUID) throws -> HandoffNote? {
        let descriptor = FetchDescriptor<HandoffNote>(
            predicate: #Predicate { $0.babyID == babyID && $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func setHandoffNote(babyID: UUID, text: String) throws {
        // Deactivate any existing notes
        let existing = try modelContext.fetch(FetchDescriptor<HandoffNote>(
            predicate: #Predicate { $0.babyID == babyID && $0.isActive }
        ))
        for note in existing {
            note.isActive = false
            note.syncStatus = .pending
        }

        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let note = HandoffNote(babyID: babyID, authorCaregiverID: currentCaregiver.id, text: text)
            modelContext.insert(note)
            syncManager.enqueue(SyncOperation(
                modelType: "HandoffNote",
                modelID: note.id,
                operation: .insert,
                payload: Data()
            ))
        }
        try modelContext.save()
    }
}

// MARK: - Encodable Payloads (Supabase-safe DTOs)

private struct BabyPayload: Encodable {
    let id: String
    let name: String
    let date_of_birth: String
    let sex: String
    let is_archived: Bool
    let updated_at: String

    init(_ baby: Baby) {
        let formatter = ISO8601DateFormatter()
        self.id = baby.id.uuidString
        self.name = baby.name
        self.date_of_birth = formatter.string(from: baby.dateOfBirth)
        self.sex = baby.sex.rawValue
        self.is_archived = baby.isArchived
        self.updated_at = formatter.string(from: baby.updatedAt)
    }
}

private struct BabyAccessPayload: Encodable {
    let id: String
    let baby_id: String
    let caregiver_id: String
    let role: String

    init(_ access: BabyAccess) {
        self.id = access.id.uuidString
        self.baby_id = access.babyID.uuidString
        self.caregiver_id = access.caregiverID.uuidString
        self.role = access.role.rawValue
    }
}

private struct InvitePayload: Encodable {
    let id: String
    let baby_id: String
    let created_by_id: String
    let role: String
    let code: String
    let expires_at: String

    init(_ invite: CaregiverInvite) {
        let formatter = ISO8601DateFormatter()
        self.id = invite.id.uuidString
        self.baby_id = invite.babyID.uuidString
        self.created_by_id = invite.createdByID.uuidString
        self.role = invite.role.rawValue
        self.code = invite.code
        self.expires_at = formatter.string(from: invite.expiresAt)
    }
}

// MARK: - Additional errors

extension RepositoryError {
    static let cannotRemoveSelf = RepositoryError.custom("You cannot remove yourself from a family")

    static func custom(_ message: String) -> RepositoryError {
        .insufficientPermissions // simplified; extend the enum as needed
    }
}
