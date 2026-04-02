import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncManager.self) private var syncManager

    @State private var viewModel: HistoryViewModel?
    @State private var showJumpToDate = false
    @State private var jumpDate = Date()

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showJumpToDate = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
        .onAppear { buildViewModel() }
        .onChange(of: appState.activeBabyID) { buildViewModel() }
        .sheet(isPresented: $showJumpToDate) {
            jumpToDateSheet
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: HistoryViewModel) -> some View {
        VStack(spacing: 0) {
            filterBar(vm: vm)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if vm.groupedEntries.isEmpty {
                emptyState(vm: vm)
            } else {
                list(vm: vm)
            }
        }
        .searchable(text: Binding(get: { vm.searchText }, set: { vm.searchText = $0 }),
                    prompt: "Search entries")
        .task { await vm.load() }
        .onChange(of: appState.activeBabyID) { Task { await vm.load() } }
        .confirmationDialog("Delete this entry?", isPresented: Binding(
            get: { vm.showDeleteConfirmation },
            set: { vm.showDeleteConfirmation = $0 }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { vm.confirmDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(item: Binding(get: { vm.editingFeed }, set: { vm.editingFeed = $0 })) { entry in
            EditFeedSheet(entry: entry) { Task { await vm.load() } }
        }
        .sheet(item: Binding(get: { vm.editingSleep }, set: { vm.editingSleep = $0 })) { entry in
            EditSleepSheet(entry: entry) { Task { await vm.load() } }
        }
        .sheet(item: Binding(get: { vm.editingDiaper }, set: { vm.editingDiaper = $0 })) { entry in
            EditDiaperSheet(entry: entry) { Task { await vm.load() } }
        }
    }

    // MARK: - Filter bar

    private func filterBar(vm: HistoryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EntryTypeFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        icon: filter.icon,
                        isActive: vm.activeFilter == filter
                    ) {
                        vm.activeFilter = filter
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - List

    private func list(vm: HistoryViewModel) -> some View {
        List {
            ForEach(vm.groupedEntries) { day in
                Section(header: dayHeader(day.date)) {
                    ForEach(day.entries, id: \.id) { entry in
                        EntryRow(entry: entry)
                            .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vm.requestDelete(id: entry.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    switch entry {
                                    case let f as FeedEntry:   vm.editingFeed   = f
                                    case let s as SleepEntry:  vm.editingSleep  = s
                                    case let d as DiaperEntry: vm.editingDiaper = d
                                    default: break
                                    }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func dayHeader(_ date: Date) -> some View {
        Text(date.historyHeaderString)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    // MARK: - Empty state

    private func emptyState(vm: HistoryViewModel) -> some View {
        ContentUnavailableView(
            vm.activeFilter == .all ? "No entries yet" : "No \(vm.activeFilter.rawValue.lowercased()) entries",
            systemImage: vm.activeFilter == .all ? "clock" : vm.activeFilter.icon,
            description: Text(vm.activeFilter == .all
                ? "Start logging to see your history here."
                : "No \(vm.activeFilter.rawValue.lowercased()) entries match your filters.")
        )
    }

    // MARK: - Jump to date sheet

    private var jumpToDateSheet: some View {
        NavigationStack {
            DatePicker("Jump to date", selection: $jumpDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .navigationTitle("Jump to Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showJumpToDate = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func buildViewModel() {
        guard let babyID = appState.activeBabyID else { return }
        if viewModel?.babyID == babyID { return }
        viewModel = HistoryViewModel(babyID: babyID, modelContext: modelContext)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                )
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date extension

extension Date {
    var historyHeaderString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
            ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy"
        return formatter.string(from: self)
    }
}
