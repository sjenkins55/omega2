import Foundation

/// Thin wrapper around the Supabase Swift SDK.
/// All Supabase SDK calls are isolated here so the rest of the app
/// stays decoupled from the specific backend.
///
/// Add the Supabase Swift SDK via SPM:
///   https://github.com/supabase/supabase-swift  (package: supabase-swift)
///
/// Once added, replace the placeholder stubs below with real SDK calls.

// MARK: - Configuration

struct SupabaseConfig {
    /// Set these in a Config.xcconfig (never hardcode in source)
    static var projectURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not set in Info.plist / xcconfig")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY not set in Info.plist / xcconfig")
        }
        return key
    }
}

// MARK: - SupabaseService

@MainActor
@Observable
final class SupabaseService {

    // MARK: Auth state
    private(set) var currentUserID: String?
    private(set) var isAuthenticated: Bool = false

    // MARK: Init
    // When the Supabase Swift SDK is added:
    // private let client = SupabaseClient(supabaseURL: SupabaseConfig.projectURL, supabaseKey: SupabaseConfig.anonKey)

    init() {
        // Restore session on init
        Task { await restoreSession() }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws {
        // SDK call: try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        // After success: currentUserID = client.auth.currentUser?.id.uuidString; isAuthenticated = true
        print("[Supabase] signInWithApple — stub")
    }

    func signInAnonymously() async throws {
        // SDK call: try await client.auth.signInAnonymously()
        print("[Supabase] signInAnonymously — stub")
    }

    func signOut() async throws {
        // SDK call: try await client.auth.signOut()
        currentUserID = nil
        isAuthenticated = false
    }

    private func restoreSession() async {
        // SDK call: let session = try? await client.auth.session
        // currentUserID = session?.user.id.uuidString; isAuthenticated = session != nil
    }

    // MARK: - CRUD

    /// Upsert (insert or update) a record. `payload` is JSON-encoded model data.
    func upsert(table: String, payload: Data) async throws {
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw SupabaseError.invalidPayload
        }
        // SDK call: try await client.from(table).upsert(json).execute()
        print("[Supabase] upsert to \(table): \(json.keys.joined(separator: ", "))")
    }

    func delete(table: String, id: String) async throws {
        // SDK call: try await client.from(table).delete().eq("id", value: id).execute()
        print("[Supabase] delete from \(table) id=\(id)")
    }

    func fetchAll(table: String, filter: String? = nil) async throws -> [[String: Any]] {
        // SDK call:
        //   var query = client.from(table).select()
        //   if let filter { query = query.filter(filter) }
        //   let response = try await query.execute()
        //   return try response.value
        print("[Supabase] fetchAll from \(table)")
        return []
    }

    // MARK: - Real-time

    /// Returns an AsyncStream of remote changes for a given table + filter.
    func subscribe(table: String, filter: String) async -> AsyncStream<RemoteChange> {
        // SDK call:
        //   let channel = client.realtimeV2.channel("public:\(table)")
        //   let changes = channel.postgresChange(AnyAction.self, schema: "public", table: table, filter: filter)
        //   await channel.subscribe()
        //   return AsyncStream { continuation in
        //       Task { for await change in changes { continuation.yield(RemoteChange(...)) } }
        //   }
        return AsyncStream { continuation in
            continuation.finish()
        }
    }

    // MARK: - Invite redemption

    func redeemInvite(code: String) async throws -> InviteRedemptionResult {
        // SDK call: Edge Function POST /functions/v1/redeem-invite { code }
        // Returns baby_id, role, family_name
        throw SupabaseError.notImplemented
    }

    func createInvite(babyID: UUID, role: CaregiverRole) async throws -> String {
        // SDK call: Edge Function POST /functions/v1/create-invite { baby_id, role }
        // Returns invite code
        throw SupabaseError.notImplemented
    }
}

// MARK: - Supporting types

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
        case .invalidPayload: return "Could not encode data for sync"
        case .notAuthenticated: return "You must be signed in to sync"
        case .notImplemented: return "This feature is not yet available"
        case .serverError(let msg): return msg
        }
    }
}
