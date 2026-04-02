import Foundation

/// Supabase backend service.
///
/// SPM package: https://github.com/supabase/supabase-swift
/// After adding the package, uncomment the import and the SDK calls below.
/// The stub implementations are in place so the project compiles immediately.

// import Supabase   ← uncomment after adding SPM package

// MARK: - Configuration

struct SupabaseConfig {
    static var projectURL: URL {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: s) else {
            fatalError("SUPABASE_URL not set in Config.xcconfig")
        }
        return url
    }

    static var anonKey: String {
        guard let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY not set in Config.xcconfig")
        }
        return k
    }
}

// MARK: - Service

@MainActor
@Observable
final class SupabaseService {

    // ── SDK client (uncomment after adding package) ──────────────────────────
    // private let client = SupabaseClient(
    //     supabaseURL: SupabaseConfig.projectURL,
    //     supabaseKey: SupabaseConfig.anonKey
    // )
    // ─────────────────────────────────────────────────────────────────────────

    private(set) var currentUserID: String?
    private(set) var isAuthenticated: Bool = false

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        // let session = try await client.auth.signInWithIdToken(
        //     credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        // )
        // currentUserID = session.user.id.uuidString
        // isAuthenticated = true
        print("[Supabase] signInWithApple — add SDK package to activate")
        currentUserID = UUID().uuidString
        isAuthenticated = true
    }

    func signInAnonymously() async throws {
        // try await client.auth.signInAnonymously()
        currentUserID = UUID().uuidString
    }

    func signOut() async throws {
        // try await client.auth.signOut()
        currentUserID = nil
        isAuthenticated = false
    }

    private func restoreSession() async {
        // if let session = try? await client.auth.session {
        //     currentUserID = session.user.id.uuidString
        //     isAuthenticated = true
        // }
    }

    // MARK: - CRUD

    /// Upsert a JSON record into the given table. Payload must contain "id" (UUID string).
    func upsert(table: String, payload: Data) async throws {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw SupabaseError.invalidPayload
        }

        // try await client
        //     .from(table)
        //     .upsert(json, onConflict: "id")
        //     .execute()

        print("[Supabase] upsert → \(table): \(json.keys.sorted().joined(separator: ", "))")
    }

    func delete(table: String, id: String) async throws {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        // try await client
        //     .from(table)
        //     .delete()
        //     .eq("id", value: id)
        //     .execute()

        print("[Supabase] delete from \(table) id=\(id)")
    }

    func fetchAll(table: String, filter: String? = nil) async throws -> [[String: Any]] {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        // var query = client.from(table).select()
        // if let filter { query = query.filter(filter) }
        // let response: [[String: Any]] = try await query.execute().value
        // return response

        return []
    }

    // MARK: - Full initial sync
    // Called once after sign-in to pull all server-side data for this user's babies.

    func initialSync(caregiverID: String) async throws -> InitialSyncResult {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        // Fetch all babies the caregiver has access to, plus their entries.
        // let accesses: [[String: Any]] = try await client
        //     .from("baby_access")
        //     .select("*, babies(*)")
        //     .eq("caregiver_id", value: caregiverID)
        //     .execute()
        //     .value
        //
        // Then fetch entries per baby:
        // let entries = try await client
        //     .from("feed_entries")
        //     .select()
        //     .in("baby_id", values: babyIDs)
        //     .gte("updated_at", value: lastSyncTimestamp)
        //     .execute()
        //     .value

        return InitialSyncResult(babies: [], feedEntries: [], sleepEntries: [],
                                 diaperEntries: [], caregivers: [])
    }

    // MARK: - Real-time

    func subscribe(table: String, filter: String) async -> AsyncStream<RemoteChange> {
        // let channel = client.realtimeV2.channel("public:\(table):\(filter)")
        // let changes = channel.postgresChange(AnyAction.self, schema: "public",
        //                                      table: table, filter: filter)
        // await channel.subscribe()
        //
        // return AsyncStream { continuation in
        //     Task {
        //         for await action in changes {
        //             switch action {
        //             case .insert(let row):
        //                 continuation.yield(RemoteChange(eventType: "INSERT",
        //                     record: row.record.jsonObject, oldRecord: nil))
        //             case .update(let row):
        //                 continuation.yield(RemoteChange(eventType: "UPDATE",
        //                     record: row.record.jsonObject, oldRecord: row.oldRecord.jsonObject))
        //             case .delete(let row):
        //                 continuation.yield(RemoteChange(eventType: "DELETE",
        //                     record: [:], oldRecord: row.oldRecord.jsonObject))
        //             default: break
        //             }
        //         }
        //     }
        // }

        return AsyncStream { $0.finish() }
    }

    // MARK: - Edge Functions

    func redeemInvite(code: String) async throws -> InviteRedemptionResult {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        // let response: InviteRedemptionResult = try await client.functions
        //     .invoke("redeem-invite", options: .init(body: ["code": code]))
        //     .value

        throw SupabaseError.notImplemented
    }

    func createInvite(babyID: UUID, role: CaregiverRole) async throws -> String {
        guard isAuthenticated else { throw SupabaseError.notAuthenticated }

        // let response: [String: String] = try await client.functions
        //     .invoke("create-invite",
        //             options: .init(body: ["baby_id": babyID.uuidString, "role": role.rawValue]))
        //     .value
        // return response["code"] ?? ""

        throw SupabaseError.notImplemented
    }
}

// MARK: - Supporting types

struct InitialSyncResult {
    let babies: [[String: Any]]
    let feedEntries: [[String: Any]]
    let sleepEntries: [[String: Any]]
    let diaperEntries: [[String: Any]]
    let caregivers: [[String: Any]]
}

struct InviteRedemptionResult {
    let babyID: UUID
    let role: CaregiverRole
    let familyName: String
}

enum SupabaseError: LocalizedError {
    case invalidPayload
    case notAuthenticated
    case notImplemented
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:    return "Could not encode data for sync"
        case .notAuthenticated:  return "You must be signed in to sync"
        case .notImplemented:    return "This feature requires an active Supabase connection"
        case .serverError(let m): return m
        }
    }
}
