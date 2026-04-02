import SwiftUI
import SwiftData

// MARK: - Environment key for current caregiver

private struct CurrentCaregiverKey: EnvironmentKey {
    static let defaultValue: Caregiver? = nil
}

extension EnvironmentValues {
    var currentCaregiver: Caregiver? {
        get { self[CurrentCaregiverKey.self] }
        set { self[CurrentCaregiverKey.self] = newValue }
    }
}

// MARK: - View modifier that resolves and injects the current caregiver

/// Apply once at the root (AppRootView / MainTabView).
/// Reads the Caregiver whose isCurrentDevice == true from SwiftData
/// and injects it into the environment so every log sheet can use it.
struct CurrentCaregiverModifier: ViewModifier {

    @Environment(AuthService.self) private var auth
    @Query(filter: #Predicate<Caregiver> { $0.isCurrentDevice }) private var localCaregivers: [Caregiver]

    func body(content: Content) -> some View {
        content
            .environment(\.currentCaregiver, resolvedCaregiver)
    }

    private var resolvedCaregiver: Caregiver? {
        // Prefer the caregiver from AuthService (already fetched), fall back to SwiftData query
        auth.currentCaregiver ?? localCaregivers.first
    }
}

extension View {
    func withCurrentCaregiver() -> some View {
        modifier(CurrentCaregiverModifier())
    }
}
