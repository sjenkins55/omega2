import Foundation

/// Every synced model carries this status.
/// The SyncManager uses it to determine what needs pushing to Supabase.
enum SyncStatus: String, Codable {
    case pending    // created/modified locally, not yet sent to server
    case synced     // matches server state
    case failed     // last sync attempt failed (will retry)
    case deleted    // soft-deleted locally, pending remote deletion
}

/// Represents a pending sync operation. Persisted to survive app restarts.
struct SyncOperation: Identifiable, Codable {
    let id: UUID
    let modelType: String       // e.g. "Baby", "FeedEntry"
    let modelID: UUID
    let operation: SyncOperationType
    let payload: Data           // JSON-encoded model snapshot
    var retryCount: Int
    var lastAttemptAt: Date?
    let createdAt: Date

    init(modelType: String, modelID: UUID, operation: SyncOperationType, payload: Data) {
        self.id = UUID()
        self.modelType = modelType
        self.modelID = modelID
        self.operation = operation
        self.payload = payload
        self.retryCount = 0
        self.lastAttemptAt = nil
        self.createdAt = Date()
    }
}

enum SyncOperationType: String, Codable {
    case insert
    case update
    case delete
}

/// Network reachability state used by the sync manager
enum NetworkState {
    case online
    case offline
}
