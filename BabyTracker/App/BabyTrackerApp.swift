import SwiftUI
import SwiftData

@main
struct BabyTrackerApp: App {

    // MARK: - SwiftData container
    // All models registered here. Container is configured once at app launch.
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            Baby.self,
            FeedEntry.self,
            SleepEntry.self,
            DiaperEntry.self,
            TemperatureEntry.self,
            Measurement.self,
            MilestoneEntry.self,
            VaccineEntry.self,
            Appointment.self,
            Medication.self,
            MedicationDose.self,
            Illness.self,
            Caregiver.self,
            BabyAccess.self,
            HandoffNote.self,
            CaregiverInvite.self,
        ])

        // Local store — no CloudKit (Supabase handles sync)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Services (shared across the app via Environment)
    @State private var supabase = SupabaseService()
    @State private var syncManager: SyncManager
    @State private var authService: AuthService
    @State private var appState = AppState()

    init() {
        let context = Self.modelContainer.mainContext
        let supa = SupabaseService()
        let sync = SyncManager(modelContext: context, supabase: supa)
        let auth = AuthService(modelContext: context, supabase: supa)
        _supabase = State(initialValue: supa)
        _syncManager = State(initialValue: sync)
        _authService = State(initialValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(Self.modelContainer)
                .environment(supabase)
                .environment(syncManager)
                .environment(authService)
                .environment(appState)
                .task { await authService.resolveInitialAuthState() }
        }
    }
}

// MARK: - App Root

struct AppRootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch auth.authState {
            case .loading:
                SplashView()
            case .anonymous where !appState.hasCompletedOnboarding:
                OnboardingView()
            case .anonymous, .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

// MARK: - AppState (global UI state)

@Observable
final class AppState {
    var activeBabyID: UUID?
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Baby Tracker")
                .font(.largeTitle.bold())
        }
    }
}

struct OnboardingView: View {
    var body: some View {
        Text("Onboarding — coming soon")
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            HistoryPlaceholder()
                .tabItem { Label("History", systemImage: "clock.fill") }
            InsightsPlaceholder()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
            ProfilePlaceholder()
                .tabItem { Label("Profile", systemImage: "person.2.fill") }
        }
    }
}

struct HistoryPlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("History", systemImage: "clock.fill",
                description: Text("All logged entries will appear here."))
            .navigationTitle("History")
        }
    }
}

struct InsightsPlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Insights", systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Charts and trends will appear here."))
            .navigationTitle("Insights")
        }
    }
}

struct ProfilePlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Profile", systemImage: "person.2.fill",
                description: Text("Baby profiles and caregiver settings."))
            .navigationTitle("Profile")
        }
    }
}
