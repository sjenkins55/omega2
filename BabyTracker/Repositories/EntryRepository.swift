import Foundation
import SwiftData

/// Central repository for all log entries (Feed, Sleep, Diaper, Temperature).
/// All writes go through here so that:
///   1. The local SwiftData store is updated immediately (offline-first)
///   2. A SyncOperation is enqueued for background push to Supabase
///
/// ViewModels call this repository — never touch ModelContext directly.

@MainActor
final class EntryRepository {

    private let modelContext: ModelContext
    private let syncManager: SyncManager
    private let currentCaregiver: Caregiver

    init(modelContext: ModelContext, syncManager: SyncManager, currentCaregiver: Caregiver) {
        self.modelContext = modelContext
        self.syncManager = syncManager
        self.currentCaregiver = currentCaregiver
    }

    // MARK: - Permission guard

    private func assertCanWrite() throws {
        guard currentCaregiver.role.canAddEntry else {
            throw RepositoryError.insufficientPermissions
        }
    }

    private func assertCanDelete() throws {
        guard currentCaregiver.role.canDeleteEntry else {
            throw RepositoryError.insufficientPermissions
        }
    }

    // MARK: - Feed

    func saveFeed(_ entry: FeedEntry) throws {
        try assertCanWrite()
        entry.caregiverID = currentCaregiver.id
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        modelContext.insert(entry)
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "FeedEntry",
            modelID: entry.id,
            operation: .insert,
            payload: try encode(entry)
        ))
    }

    func updateFeed(_ entry: FeedEntry) throws {
        try assertCanWrite()
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "FeedEntry",
            modelID: entry.id,
            operation: .update,
            payload: try encode(entry)
        ))
    }

    func deleteFeed(_ entry: FeedEntry) throws {
        try assertCanDelete()
        entry.syncStatus = .deleted
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "FeedEntry",
            modelID: entry.id,
            operation: .delete,
            payload: Data()
        ))
        modelContext.delete(entry)
        try modelContext.save()
    }

    func feedEntries(for babyID: UUID, limit: Int? = nil) throws -> [FeedEntry] {
        var descriptor = FetchDescriptor<FeedEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return try modelContext.fetch(descriptor)
    }

    func lastFeed(for babyID: UUID) throws -> FeedEntry? {
        try feedEntries(for: babyID, limit: 1).first
    }

    // MARK: - Sleep

    func saveSleep(_ entry: SleepEntry) throws {
        try assertCanWrite()
        entry.caregiverID = currentCaregiver.id
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        modelContext.insert(entry)
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "SleepEntry",
            modelID: entry.id,
            operation: .insert,
            payload: try encode(entry)
        ))
    }

    func updateSleep(_ entry: SleepEntry) throws {
        try assertCanWrite()
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "SleepEntry",
            modelID: entry.id,
            operation: .update,
            payload: try encode(entry)
        ))
    }

    func deleteSleep(_ entry: SleepEntry) throws {
        try assertCanDelete()
        entry.syncStatus = .deleted
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "SleepEntry",
            modelID: entry.id,
            operation: .delete,
            payload: Data()
        ))
        modelContext.delete(entry)
        try modelContext.save()
    }

    func sleepEntries(for babyID: UUID, limit: Int? = nil) throws -> [SleepEntry] {
        var descriptor = FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return try modelContext.fetch(descriptor)
    }

    func lastSleep(for babyID: UUID) throws -> SleepEntry? {
        try sleepEntries(for: babyID, limit: 1).first
    }

    func ongoingSleep(for babyID: UUID) throws -> SleepEntry? {
        let descriptor = FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.endTime == nil }
        )
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Diaper

    func saveDiaper(_ entry: DiaperEntry) throws {
        try assertCanWrite()
        entry.caregiverID = currentCaregiver.id
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        modelContext.insert(entry)
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "DiaperEntry",
            modelID: entry.id,
            operation: .insert,
            payload: try encode(entry)
        ))
    }

    func deleteDiaper(_ entry: DiaperEntry) throws {
        try assertCanDelete()
        entry.syncStatus = .deleted
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "DiaperEntry",
            modelID: entry.id,
            operation: .delete,
            payload: Data()
        ))
        modelContext.delete(entry)
        try modelContext.save()
    }

    func diaperEntries(for babyID: UUID, limit: Int? = nil) throws -> [DiaperEntry] {
        var descriptor = FetchDescriptor<DiaperEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return try modelContext.fetch(descriptor)
    }

    func lastDiaper(for babyID: UUID) throws -> DiaperEntry? {
        try diaperEntries(for: babyID, limit: 1).first
    }

    // MARK: - Temperature

    func saveTemperature(_ entry: TemperatureEntry) throws {
        try assertCanWrite()
        entry.caregiverID = currentCaregiver.id
        entry.updatedAt = Date()
        entry.syncStatus = .pending
        modelContext.insert(entry)
        try modelContext.save()
        syncManager.enqueue(SyncOperation(
            modelType: "TemperatureEntry",
            modelID: entry.id,
            operation: .insert,
            payload: try encode(entry)
        ))
    }

    // MARK: - Encoding helper

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }
}

// MARK: - Error

enum RepositoryError: LocalizedError {
    case insufficientPermissions
    case notFound

    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .notFound:
            return "The requested record was not found"
        }
    }
}
