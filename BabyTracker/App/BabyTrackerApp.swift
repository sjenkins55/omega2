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
    @State private var subscriptionService = SubscriptionService()
    @State private var toastContainer = ToastContainer()

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
                .environment(subscriptionService)
                .environment(toastContainer)
                .task { await authService.resolveInitialAuthState() }
                .task { NotificationService.shared.registerCategories() }
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

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
            if hSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .toastContainer()
        .withCurrentCaregiver()
    }

    // MARK: iPhone — TabView

    private var iPhoneLayout: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.2.fill") }
        }
    }

    // MARK: iPad — NavigationSplitView with sidebar

    @State private var selectedTab: SidebarTab = .home

    private var iPadLayout: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Baby Tracker")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case .home:     HomeView()
            case .history:  HistoryView()
            case .insights: InsightsView()
            case .profile:  ProfileView()
            }
        }
    }
}

enum SidebarTab: String, CaseIterable {
    case home, history, insights, profile

    var title: String {
        switch self {
        case .home:     return "Home"
        case .history:  return "History"
        case .insights: return "Insights"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .history:  return "clock.fill"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile:  return "person.2.fill"
        }
    }
}
