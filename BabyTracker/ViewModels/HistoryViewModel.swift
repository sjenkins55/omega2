import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class HistoryViewModel {

    // MARK: - State

    private(set) var groupedEntries: [HistoryDay] = []
    private(set) var isLoading = false
    var searchText: String = "" { didSet { applyFilters() } }
    var activeFilter: EntryTypeFilter = .all { didSet { applyFilters() } }
    var activeCaregiverFilter: UUID? = nil { didSet { applyFilters() } }
    var errorMessage: String?

    // Entry being edited
    var editingFeed: FeedEntry? = nil
    var editingSleep: SleepEntry? = nil
    var editingDiaper: DiaperEntry? = nil
    var showDeleteConfirmation = false
    var pendingDeleteID: UUID? = nil

    private let babyID: UUID
    private let modelContext: ModelContext
    private var allEntries: [any HistoryEntry] = []

    // MARK: - Init

    init(babyID: UUID, modelContext: ModelContext) {
        self.babyID = babyID
        self.modelContext = modelContext
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        do {
            var entries: [any HistoryEntry] = []
            entries += try fetchFeeds()
            entries += try fetchSleeps()
            entries += try fetchDiapers()
            entries += try fetchTemps()
            allEntries = entries
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Delete

    func requestDelete(id: UUID) {
        pendingDeleteID = id
        showDeleteConfirmation = true
    }

    func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        deleteEntry(id: id)
        pendingDeleteID = nil
        Task { await load() }
    }

    private func deleteEntry(id: UUID) {
        // Try each type
        if let entry = allEntries.first(where: { $0.id == id }) {
            switch entry {
            case let f as FeedEntry:   modelContext.delete(f)
            case let s as SleepEntry:  modelContext.delete(s)
            case let d as DiaperEntry: modelContext.delete(d)
            case let t as TemperatureEntry: modelContext.delete(t)
            default: break
            }
            try? modelContext.save()
        }
    }

    // MARK: - Filtering & grouping

    private func applyFilters() {
        var filtered = allEntries

        // Type filter
        if activeFilter != .all {
            filtered = filtered.filter { entry in
                switch activeFilter {
                case .all: return true
                case .feed: return entry is FeedEntry
                case .sleep: return entry is SleepEntry
                case .diaper: return entry is DiaperEntry
                case .health: return entry is TemperatureEntry
                }
            }
        }

        // Caregiver filter
        if let cid = activeCaregiverFilter {
            filtered = filtered.filter { $0.caregiverID == cid }
        }

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            filtered = filtered.filter { $0.searchableText.lowercased().contains(q) }
        }

        // Sort descending
        filtered.sort { $0.timestamp > $1.timestamp }

        // Group by calendar day
        let calendar = Calendar.current
        var groups: [Date: [any HistoryEntry]] = [:]
        for entry in filtered {
            let day = calendar.startOfDay(for: entry.timestamp)
            groups[day, default: []].append(entry)
        }

        groupedEntries = groups.map { HistoryDay(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Fetches

    private func fetchFeeds() throws -> [FeedEntry] {
        try modelContext.fetch(FetchDescriptor<FeedEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
    }

    private func fetchSleeps() throws -> [SleepEntry] {
        try modelContext.fetch(FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
    }

    private func fetchDiapers() throws -> [DiaperEntry] {
        try modelContext.fetch(FetchDescriptor<DiaperEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
    }

    private func fetchTemps() throws -> [TemperatureEntry] {
        try modelContext.fetch(FetchDescriptor<TemperatureEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.syncStatus != .deleted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))
    }
}

// MARK: - Supporting types

protocol HistoryEntry: AnyObject {
    var id: UUID { get }
    var timestamp: Date { get }
    var caregiverID: UUID { get }
    var searchableText: String { get }
}

extension FeedEntry: HistoryEntry {
    var searchableText: String { [feedType.rawValue, foodName, formulaBrand, notes].compactMap { $0 }.joined(separator: " ") }
}
extension SleepEntry: HistoryEntry {
    var searchableText: String { [sleepType.rawValue, location.rawValue, notes].compactMap { $0 }.joined(separator: " ") }
}
extension DiaperEntry: HistoryEntry {
    var searchableText: String { [diaperType.rawValue, stoolColor?.rawValue, notes].compactMap { $0 }.joined(separator: " ") }
}
extension TemperatureEntry: HistoryEntry {
    var searchableText: String { [method.rawValue, notes].compactMap { $0 }.joined(separator: " ") }
}

struct HistoryDay: Identifiable {
    var id: Date { date }
    let date: Date
    let entries: [any HistoryEntry]
}

enum EntryTypeFilter: String, CaseIterable {
    case all = "All"
    case feed = "Feed"
    case sleep = "Sleep"
    case diaper = "Diaper"
    case health = "Health"

    var icon: String {
        switch self {
        case .all:    return "list.bullet"
        case .feed:   return "drop.fill"
        case .sleep:  return "moon.fill"
        case .diaper: return "drop.triangle.fill"
        case .health: return "cross.fill"
        }
    }
}
