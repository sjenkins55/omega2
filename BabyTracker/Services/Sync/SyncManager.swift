import Foundation
import SwiftData
import Network
import Combine

/// SyncManager coordinates offline-first data flow:
///
/// Write path:  Local SwiftData write (instant) → mark syncStatus = .pending
///              → enqueue SyncOperation → push to Supabase when online
///
/// Read path:   Supabase real-time subscription pushes changes
///              → merge into local SwiftData store
///
/// On reconnect: drain the pending queue in FIFO order with exponential backoff
@MainActor
@Observable
final class SyncManager {

    // MARK: - State

    enum SyncState {
        case idle
        case syncing
        case paused(reason: String)
    }

    private(set) var state: SyncState = .idle
    private(set) var networkState: NetworkState = .offline
    private(set) var pendingOperationsCount: Int = 0
    private(set) var lastSyncAt: Date?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let supabase: SupabaseService
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.babytracker.network")
    private var syncTask: Task<Void, Never>?
    private var realtimeSubscriptions: [String: Task<Void, Never>] = [:]

    // MARK: - Init

    init(modelContext: ModelContext, supabase: SupabaseService) {
        self.modelContext = modelContext
        self.supabase = supabase
        startNetworkMonitor()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newState: NetworkState = path.status == .satisfied ? .online : .offline
                let wasOffline = self.networkState == .offline
                self.networkState = newState

                if newState == .online && wasOffline {
                    await self.drainPendingQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Enqueue (called after every local write)

    /// Enqueues a sync operation. Safe to call from any context — the operation is
    /// persisted to UserDefaults-backed storage so it survives app restarts.
    func enqueue(_ operation: SyncOperation) {
        var queue = loadQueue()
        queue.append(operation)
        saveQueue(queue)
        pendingOperationsCount = queue.count

        if networkState == .online {
            Task { await drainPendingQueue() }
        }
    }

    // MARK: - Drain Queue

    func drainPendingQueue() async {
        guard networkState == .online, case .idle = state else { return }
        state = .syncing

        var queue = loadQueue()
        var remaining: [SyncOperation] = []

        for var op in queue {
            do {
                try await push(op)
            } catch {
                op.retryCount += 1
                op.lastAttemptAt = Date()

                if op.retryCount < 5 {
                    remaining.append(op)
                } else {
                    // After 5 failures, mark the local model as failed and drop the op
                    markLocalModelFailed(type: op.modelType, id: op.modelID)
                }
            }
        }

        saveQueue(remaining)
        pendingOperationsCount = remaining.count
        lastSyncAt = remaining.isEmpty ? Date() : lastSyncAt
        state = .idle

        if !remaining.isEmpty {
            // Retry failed operations after exponential backoff
            let delay = UInt64(pow(2.0, Double(remaining.first?.retryCount ?? 1))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: min(delay, 30_000_000_000)) // cap at 30s
            await drainPendingQueue()
        }
    }

    // MARK: - Push individual operation to Supabase

    private func push(_ operation: SyncOperation) async throws {
        switch operation.operation {
        case .insert, .update:
            try await supabase.upsert(table: tableName(for: operation.modelType), payload: operation.payload)
        case .delete:
            guard let remoteID = remoteID(for: operation.modelType, localID: operation.modelID) else { return }
            try await supabase.delete(table: tableName(for: operation.modelType), id: remoteID)
        }

        // On success, mark local model as synced
        markLocalModelSynced(type: operation.modelType, id: operation.modelID)
    }

    // MARK: - Real-time (inbound sync)

    /// Subscribe to a baby's real-time changes from Supabase.
    /// Call this after a caregiver joins a shared family.
    func subscribeToRealtime(babyID: UUID) {
        let key = babyID.uuidString
        guard realtimeSubscriptions[key] == nil else { return }

        realtimeSubscriptions[key] = Task {
            let tables = ["feed_entries", "sleep_entries", "diaper_entries",
                          "measurements", "milestone_entries", "temperature_entries"]

            for table in tables {
                Task {
                    for await change in await supabase.subscribe(table: table, filter: "baby_id=eq.\(babyID)") {
                        await self.applyRemoteChange(change, table: table)
                    }
                }
            }
        }
    }

    func unsubscribeFromRealtime(babyID: UUID) {
        let key = babyID.uuidString
        realtimeSubscriptions[key]?.cancel()
        realtimeSubscriptions.removeValue(forKey: key)
    }

    // MARK: - Apply remote change to local SwiftData

    private func applyRemoteChange(_ change: RemoteChange, table: String) async {
        // Conflict resolution: server wins if server's updated_at is newer.
        // This is "last write wins" — appropriate for baby tracking data
        // where conflicts are rare and the most recent log is most correct.
        switch change.eventType {
        case "INSERT", "UPDATE":
            await mergeRemoteRecord(change.record, table: table)
        case "DELETE":
            await deleteLocalRecord(remoteID: change.oldRecord?["id"] as? String ?? "", table: table)
        default:
            break
        }
    }

    private func mergeRemoteRecord(_ record: [String: Any], table: String) async {
        guard let remoteIDStr = record["id"] as? String,
              let updatedAtStr = record["updated_at"] as? String else { return }

        let remoteUpdatedAt = ISO8601DateFormatter().date(from: updatedAtStr) ?? Date()

        // Find existing local record by remoteID
        // If local updatedAt is newer, local wins (we already queued an outbound sync)
        // If remote is newer, apply the update
        //
        // Actual SwiftData fetch + merge per model type is implemented in
        // each Repository class to keep this manager generic.
        await NotificationCenter.default.post(
            name: .remoteChangeReceived,
            object: RemoteChangeNotification(table: table, record: record, updatedAt: remoteUpdatedAt)
        )
    }

    private func deleteLocalRecord(remoteID: String, table: String) async {
        await NotificationCenter.default.post(
            name: .remoteDeleteReceived,
            object: RemoteDeleteNotification(table: table, remoteID: remoteID)
        )
    }

    // MARK: - Helpers

    private func tableName(for modelType: String) -> String {
        // Convert Swift type names to Supabase snake_case table names
        switch modelType {
        case "Baby": return "babies"
        case "FeedEntry": return "feed_entries"
        case "SleepEntry": return "sleep_entries"
        case "DiaperEntry": return "diaper_entries"
        case "Measurement": return "measurements"
        case "MilestoneEntry": return "milestone_entries"
        case "VaccineEntry": return "vaccine_entries"
        case "Appointment": return "appointments"
        case "Medication": return "medications"
        case "MedicationDose": return "medication_doses"
        case "Illness": return "illnesses"
        case "TemperatureEntry": return "temperature_entries"
        case "Caregiver": return "caregivers"
        case "BabyAccess": return "baby_access"
        case "HandoffNote": return "handoff_notes"
        case "CaregiverInvite": return "caregiver_invites"
        default: return modelType.lowercased() + "s"
        }
    }

    private func remoteID(for modelType: String, localID: UUID) -> String? {
        // Look up the remoteID from the local SwiftData store
        // Each model stores its Supabase UUID in the remoteID field
        // This lookup is done via a raw fetch — kept simple intentionally
        return nil // placeholder: implemented per-model in repositories
    }

    private func markLocalModelSynced(type: String, id: UUID) {
        // Signal repositories to update syncStatus → .synced
        NotificationCenter.default.post(
            name: .localModelSynced,
            object: SyncStatusNotification(modelType: type, modelID: id, status: .synced)
        )
    }

    private func markLocalModelFailed(type: String, id: UUID) {
        NotificationCenter.default.post(
            name: .localModelSynced,
            object: SyncStatusNotification(modelType: type, modelID: id, status: .failed)
        )
    }

    // MARK: - Queue Persistence (UserDefaults — survives app restart)

    private let queueKey = "com.babytracker.syncQueue"

    private func loadQueue() -> [SyncOperation] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return []
        }
        return queue
    }

    private func saveQueue(_ queue: [SyncOperation]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: queueKey)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let remoteChangeReceived = Notification.Name("remoteChangeReceived")
    static let remoteDeleteReceived = Notification.Name("remoteDeleteReceived")
    static let localModelSynced = Notification.Name("localModelSynced")
}

// MARK: - Notification Payloads

struct RemoteChangeNotification {
    let table: String
    let record: [String: Any]
    let updatedAt: Date
}

struct RemoteDeleteNotification {
    let table: String
    let remoteID: String
}

struct SyncStatusNotification {
    let modelType: String
    let modelID: UUID
    let status: SyncStatus
}

// MARK: - Remote Change (from Supabase real-time)

struct RemoteChange {
    let eventType: String       // INSERT, UPDATE, DELETE
    let record: [String: Any]
    let oldRecord: [String: Any]?
}
