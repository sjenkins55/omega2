import Foundation
import SwiftData
import AuthenticationServices
import CryptoKit

/// Manages authentication state and the current caregiver identity.
/// Supports:
///   - Sign in with Apple (primary)
///   - Anonymous / guest mode (no account required to start using the app)
///   - Account linking (upgrade anonymous → Apple ID without losing data)

@MainActor
@Observable
final class AuthService {

    enum AuthState {
        case loading
        case anonymous(Caregiver)
        case authenticated(Caregiver)
    }

    private(set) var authState: AuthState = .loading
    private let modelContext: ModelContext
    private let supabase: SupabaseService

    var currentCaregiver: Caregiver? {
        switch authState {
        case .anonymous(let c), .authenticated(let c): return c
        case .loading: return nil
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    init(modelContext: ModelContext, supabase: SupabaseService) {
        self.modelContext = modelContext
        self.supabase = supabase
    }

    // MARK: - Startup

    func resolveInitialAuthState() async {
        // 1. Check if there's a local caregiver marked as current device
        if let existing = try? fetchCurrentDeviceCaregiver() {
            authState = supabase.isAuthenticated ? .authenticated(existing) : .anonymous(existing)
            return
        }
        // 2. First launch — create anonymous caregiver, prompt for name
        let anonymous = Caregiver(displayName: "Parent", role: .admin, isCurrentDevice: true)
        modelContext.insert(anonymous)
        try? modelContext.save()
        authState = .anonymous(anonymous)
    }

    // MARK: - Sign In with Apple

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            print("[Auth] Apple Sign In failed: \(error.localizedDescription)")
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { return }

            do {
                try await supabase.signInWithApple(idToken: idToken, nonce: nonce)

                // Update the local caregiver with the Supabase user ID
                if let caregiver = currentCaregiver, let userID = supabase.currentUserID {
                    caregiver.supabaseUserID = userID
                    caregiver.syncStatus = .pending
                    if let fullName = credential.fullName {
                        let name = [fullName.givenName, fullName.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        if !name.isEmpty { caregiver.displayName = name }
                    }
                    try? modelContext.save()
                    authState = .authenticated(caregiver)
                }
            } catch {
                print("[Auth] Supabase Apple sign in failed: \(error)")
            }
        }
    }

    // MARK: - Anonymous → Authenticated upgrade

    /// Upgrade an anonymous account to a full account without losing local data.
    /// All locally-created babies and entries retain their IDs — the sync manager
    /// will push them to Supabase after auth is established.
    func linkAppleAccount(result: Result<ASAuthorization, Error>) async {
        // Same flow as sign-in; local data is preserved because we keep the same
        // local Caregiver object — only the supabaseUserID field is updated.
        await handleAppleSignIn(result: result)
    }

    func signOut() async throws {
        try await supabase.signOut()

        // Keep local data; just clear the auth link
        if let caregiver = currentCaregiver {
            caregiver.supabaseUserID = nil
            caregiver.syncStatus = .pending
            try? modelContext.save()
            authState = .anonymous(caregiver)
        }
    }

    // MARK: - Nonce (for Sign In with Apple)

    private(set) var currentNonce: String?

    func prepareNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Helpers

    private func fetchCurrentDeviceCaregiver() throws -> Caregiver? {
        let descriptor = FetchDescriptor<Caregiver>(
            predicate: #Predicate { $0.isCurrentDevice }
        )
        return try modelContext.fetch(descriptor).first
    }
}
