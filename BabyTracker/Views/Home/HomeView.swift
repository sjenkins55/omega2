import SwiftUI
import SwiftData

struct HomeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.currentCaregiver) private var currentCaregiver

    // Fetch all non-archived babies for the switcher
    @Query(filter: #Predicate<Baby> { !$0.isArchived }, sort: \Baby.dateOfBirth)
    private var babies: [Baby]

    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, let baby = activeBaby {
                    content(vm: vm, baby: baby)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onChange(of: appState.activeBabyID) { buildViewModel() }
        .onChange(of: babies) { setDefaultBaby() }
        .onAppear {
            setDefaultBaby()
            buildViewModel()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(vm: HomeViewModel, baby: Baby) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    babySwitcher
                    WakeWindowBar(vm: vm)
                    statusCards(vm: vm)
                    todaySummary(vm: vm)
                    Spacer(minLength: 80) // room for FAB
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            QuickLogFAB(sheet: Binding(
                get: { vm.activeSheet },
                set: { vm.activeSheet = $0 }
            ))
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(item: Binding(get: { vm.activeSheet }, set: { vm.activeSheet = $0 })) { sheet in
            logSheet(sheet, vm: vm)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Baby Switcher

    private var babySwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(babies) { baby in
                    BabyChip(baby: baby, isActive: baby.id == appState.activeBabyID) {
                        appState.activeBabyID = baby.id
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Status Cards

    private func statusCards(vm: HomeViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatusCard(
                    icon: "drop.fill",
                    iconColor: .blue,
                    title: "Last Fed",
                    primary: vm.lastFeedElapsed,
                    secondary: lastFeedDetail(vm.lastFeed),
                    action: { vm.activeSheet = .feed }
                )
                StatusCard(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    title: vm.ongoingSleep != nil ? "Sleeping" : "Last Sleep",
                    primary: vm.ongoingSleep != nil ? vm.ongoingSleepDuration : vm.lastSleepElapsed,
                    secondary: vm.ongoingSleep != nil ? "Tap to stop" : lastSleepDetail(vm.lastSleep),
                    isHighlighted: vm.ongoingSleep != nil,
                    action: {
                        if vm.ongoingSleep != nil { vm.stopOngoingSleep() }
                        else { vm.activeSheet = .sleep }
                    }
                )
            }
            HStack(spacing: 12) {
                StatusCard(
                    icon: "drop.triangle.fill",
                    iconColor: .orange,
                    title: "Last Diaper",
                    primary: vm.lastDiaperElapsed,
                    secondary: vm.lastDiaper.map { $0.diaperType.rawValue } ?? "None logged",
                    action: { vm.activeSheet = .diaper }
                )
                StatusCard(
                    icon: "chart.bar.fill",
                    iconColor: .green,
                    title: "Today",
                    primary: "\(vm.todayFeedCount) feeds",
                    secondary: "\(vm.todaySleepMinutes)m sleep • \(vm.todayDiaperCount) diapers",
                    action: nil
                )
            }
        }
    }

    // MARK: - Today Summary

    private func todaySummary(vm: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
            SummaryRow(icon: "drop.fill", color: .blue,
                       label: "Feeding",
                       value: vm.todayFeedCount == 0 ? "None logged" :
                              "\(vm.todayFeedCount) feeds" +
                              (vm.todayFeedVolumeMl > 0 ? " · \(Int(vm.todayFeedVolumeMl))ml" : ""))
            SummaryRow(icon: "moon.fill", color: .indigo,
                       label: "Sleep",
                       value: vm.todaySleepMinutes == 0 ? "None logged" :
                              "\(vm.todaySleepMinutes / 60)h \(vm.todaySleepMinutes % 60)m total")
            SummaryRow(icon: "drop.triangle.fill", color: .orange,
                       label: "Diapers",
                       value: vm.todayDiaperCount == 0 ? "None logged" : "\(vm.todayDiaperCount) changes")
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sync indicator in toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            SyncStatusIndicator(syncManager: syncManager)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
            Text("No babies yet")
                .font(.title2.bold())
            Text("Add a baby profile to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Sheet routing

    @ViewBuilder
    private func logSheet(_ sheet: HomeSheet, vm: HomeViewModel) -> some View {
        let name = activeBaby?.name ?? "Baby"
        switch sheet {
        case .feed:
            FeedLogSheet(babyID: vm.babyID, babyName: name) { vm.reload() }
        case .sleep:
            SleepLogSheet(babyID: vm.babyID, babyName: name) { vm.reload() }
        case .diaper:
            DiaperLogSheet(babyID: vm.babyID) { vm.reload() }
        case .other:
            MoreLogSheet(babyID: vm.babyID, babyName: name) { vm.reload() }
        }
    }

    // MARK: - Helpers

    private var activeBaby: Baby? {
        guard let id = appState.activeBabyID else { return babies.first }
        return babies.first { $0.id == id }
    }

    private func setDefaultBaby() {
        if appState.activeBabyID == nil, let first = babies.first {
            appState.activeBabyID = first.id
        }
    }

    private func buildViewModel() {
        guard let babyID = appState.activeBabyID ?? babies.first?.id else { return }
        if viewModel?.babyID == babyID { return }

        // Use authenticated caregiver if available, otherwise create a temporary admin
        // caregiver for the device so the UI functions in anonymous mode.
        let caregiver = currentCaregiver ?? {
            let c = Caregiver(displayName: "Me", role: .admin, isCurrentDevice: true)
            modelContext.insert(c)
            try? modelContext.save()
            return c
        }()
        let entryRepo = EntryRepository(modelContext: modelContext, syncManager: syncManager, currentCaregiver: caregiver)
        let babyRepo  = BabyRepository(modelContext: modelContext, syncManager: syncManager, currentCaregiver: caregiver)
        let vm = HomeViewModel(babyID: babyID, modelContext: modelContext, entryRepo: entryRepo, babyRepo: babyRepo)
        vm.babyName = babies.first { $0.id == babyID }?.name ?? "Baby"
        viewModel = vm
    }

    // Detail helpers
    private func lastFeedDetail(_ feed: FeedEntry?) -> String {
        guard let feed else { return "None logged" }
        switch feed.feedType {
        case .breast:
            let mins = Int(feed.totalDurationSeconds / 60)
            return "\(mins)m · \(feed.lastSide?.rawValue.capitalized ?? "Both")"
        case .bottle:
            return feed.volumeMl.map { "\(Int($0))ml" } ?? "Bottle"
        case .solids:
            return feed.foodName ?? "Solids"
        case .pump:
            let total = (feed.pumpLeftMl ?? 0) + (feed.pumpRightMl ?? 0)
            return total > 0 ? "\(Int(total))ml pumped" : "Pump session"
        }
    }

    private func lastSleepDetail(_ sleep: SleepEntry?) -> String {
        guard let sleep else { return "None logged" }
        guard let dur = sleep.durationSeconds else { return "In progress" }
        let m = Int(dur / 60)
        return "\(m / 60)h \(m % 60)m · \(sleep.sleepType.rawValue)"
    }
}
