import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var auth
    @Environment(SyncManager.self) private var syncManager
    @Environment(SubscriptionService.self) private var sub

    @Query(filter: #Predicate<Baby> { !$0.isArchived }, sort: \Baby.dateOfBirth)
    private var babies: [Baby]

    @Query private var caregivers: [Caregiver]

    @State private var showAddBaby = false
    @State private var showInvite = false
    @State private var showSignIn = false
    @State private var showPaywall = false
    @State private var editingBaby: Baby? = nil
    @State private var selectedBabyForInvite: UUID? = nil

    var body: some View {
        NavigationStack {
            List {
                babiesSection
                caregiverSection
                healthSection
                syncSection
                settingsSection
                appSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBaby = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddBaby) {
            AddBabySheet { showAddBaby = false }
        }
        .sheet(item: $editingBaby) { baby in
            AddBabySheet(existing: baby) { editingBaby = nil }
        }
        .sheet(isPresented: $showInvite) {
            if let babyID = selectedBabyForInvite {
                InviteView(babyID: babyID)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: .addBaby)
        }
    }

    // MARK: - Babies section

    private var babiesSection: some View {
        Section("Babies") {
            ForEach(babies) { baby in
                BabyRow(
                    baby: baby,
                    isActive: baby.id == appState.activeBabyID,
                    onSelect: { appState.activeBabyID = baby.id },
                    onEdit: { editingBaby = baby },
                    onInvite: {
                        selectedBabyForInvite = baby.id
                        showInvite = true
                    }
                )
            }
            Button {
                if sub.canAddBaby(currentCount: babies.count) {
                    showAddBaby = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label("Add Baby", systemImage: "plus.circle.fill")
                    if !sub.canAddBaby(currentCount: babies.count) {
                        Spacer()
                        Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Caregiver section

    private var caregiverSection: some View {
        Section {
            if let current = auth.currentCaregiver {
                HStack(spacing: 12) {
                    BabyAvatar(baby: Baby(name: current.displayName, dateOfBirth: Date()), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(current.role.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if auth.isAuthenticated {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            ForEach(otherCaregivers) { caregiver in
                CaregiverRow(caregiver: caregiver)
            }

            NavigationLink {
                CaregiverManagementView()
            } label: {
                Label("Manage Caregivers", systemImage: "person.badge.plus")
            }
        } header: {
            Text("Your Family")
        }
    }

    // MARK: - Sync section

    private var syncSection: some View {
        Section("Sync & Account") {
            if !auth.isAuthenticated {
                Button {
                    showSignIn = true
                } label: {
                    HStack {
                        Label("Sign in with Apple", systemImage: "applelogo")
                        Spacer()
                        Text("Sync data across devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            } else {
                HStack {
                    Label("iCloud Sync", systemImage: "icloud.fill")
                    Spacer()
                    Image(systemName: syncManager.networkState == .online ? "checkmark.circle.fill" : "wifi.slash")
                        .foregroundStyle(syncManager.networkState == .online ? .green : .orange)
                }
                if syncManager.pendingOperationsCount > 0 {
                    HStack {
                        Label("\(syncManager.pendingOperationsCount) pending", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }
        }
    }

    // MARK: - Health section (per active baby)

    private var healthSection: some View {
        Section("Health & Growth") {
            if let baby = activeBaby {
                NavigationLink {
                    GrowthView(baby: baby)
                } label: {
                    Label("Growth Charts", systemImage: "chart.line.uptrend.xyaxis")
                }
                NavigationLink {
                    VaccineScheduleView(baby: baby)
                } label: {
                    Label("Vaccine Schedule", systemImage: "cross.vial.fill")
                }
                NavigationLink {
                    MilestoneGalleryView(baby: baby)
                } label: {
                    Label("Milestones", systemImage: "star.circle.fill")
                }
                NavigationLink {
                    MedicationManagementView(baby: baby)
                } label: {
                    Label("Medications", systemImage: "pill.fill")
                }
                NavigationLink {
                    IllnessLogView(baby: baby)
                } label: {
                    Label("Illness Log", systemImage: "cross.case.fill")
                }
                NavigationLink {
                    AppointmentManagementView(baby: baby)
                } label: {
                    Label("Appointments", systemImage: "calendar.badge.plus")
                }
            }
        }
    }

    private var activeBaby: Baby? {
        guard let id = appState.activeBabyID else { return babies.first }
        return babies.first { $0.id == id }
    }

    // MARK: - Settings section

    private var settingsSection: some View {
        Section("Settings") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("Notifications", systemImage: "bell.badge.fill")
            }
            NavigationLink {
                UnitsSettingsView()
            } label: {
                Label("Units & Display", systemImage: "ruler.fill")
            }
            NavigationLink {
                DataExportView()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - App info section

    private var appSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://github.com/anthropics/claude-code/issues")!) {
                Label("Send Feedback", systemImage: "envelope")
            }
        } header: {
            Text("App")
        }
    }

    private var otherCaregivers: [Caregiver] {
        caregivers.filter { !$0.isCurrentDevice }
    }
}

// MARK: - Baby Row

struct BabyRow: View {
    let baby: Baby
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onInvite: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                BabyAvatar(baby: baby, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(baby.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(ageString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button { onInvite() } label: { Label("Invite Caregiver", systemImage: "person.badge.plus") }
        }
    }

    private var ageString: String {
        let months = baby.ageInMonths
        if months < 1 { return "\(baby.ageInDays) days old" }
        if months < 24 { return "\(months) months old" }
        return "\(months / 12) years old"
    }
}

// MARK: - Caregiver Row

struct CaregiverRow: View {
    let caregiver: Caregiver

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(caregiver.displayName.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(caregiver.displayName)
                    .font(.subheadline)
                Text(caregiver.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if caregiver.syncStatus == .synced {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Bundle helpers

extension Bundle {
    var appVersion: String {
        "\(infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
    }
}

// MARK: - Placeholder nav views

struct NotificationSettingsView: View {
    var body: some View {
        List {
            Section("Feed Reminders") {
                Toggle("Feed reminder", isOn: .constant(true))
                Stepper("Every 3 hours", value: .constant(3), in: 1...8)
            }
            Section("Other") {
                Toggle("Diaper reminder", isOn: .constant(false))
                Toggle("Medication reminders", isOn: .constant(true))
                Toggle("Daily summary", isOn: .constant(false))
            }
        }
        .navigationTitle("Notifications")
    }
}

struct UnitsSettingsView: View {
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("use24Hour") private var use24Hour = false

    var body: some View {
        List {
            Section("Measurements") {
                Picker("Weight", selection: $useMetric) {
                    Text("kg").tag(true)
                    Text("lbs").tag(false)
                }
                Toggle("24-hour time", isOn: $use24Hour)
            }
        }
        .navigationTitle("Units & Display")
    }
}

struct DataExportView: View {
    @State private var exportRange: ExportRange = .last30Days
    @State private var isExporting = false

    var body: some View {
        List {
            Section("Date Range") {
                Picker("Range", selection: $exportRange) {
                    ForEach(ExportRange.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                Button {
                    isExporting = true
                } label: {
                    Label("Export as CSV", systemImage: "tablecells")
                }
                Button {
                    isExporting = true
                } label: {
                    Label("Export as PDF Report", systemImage: "doc.richtext")
                }
            } footer: {
                Text("Exported files include all entries for the selected period.")
            }
        }
        .navigationTitle("Export Data")
        .overlay {
            if isExporting {
                ProgressView("Preparing export…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

enum ExportRange: CaseIterable {
    case last7Days, last30Days, last90Days, allTime
    var label: String {
        switch self {
        case .last7Days:  return "Last 7 days"
        case .last30Days: return "Last 30 days"
        case .last90Days: return "Last 90 days"
        case .allTime:    return "All time"
        }
    }
}
