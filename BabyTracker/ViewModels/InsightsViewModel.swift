import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class InsightsViewModel {

    // MARK: - Feed chart data
    private(set) var feedDailyData: [DailyFeedPoint] = []
    private(set) var avgFeedIntervalMinutes: Double = 0
    private(set) var totalFeedsThisWeek: Int = 0

    // MARK: - Sleep chart data
    private(set) var sleepDailyData: [DailySleepPoint] = []
    private(set) var avgNightSleepMinutes: Double = 0
    private(set) var longestSleepStretchMinutes: Double = 0

    // MARK: - Diaper chart data
    private(set) var diaperDailyData: [DailyDiaperPoint] = []
    private(set) var avgDiapersPerDay: Double = 0

    // MARK: - Range
    var selectedRange: InsightRange = .week { didSet { Task { await load() } } }

    private(set) var isLoading = false
    var errorMessage: String? = nil

    let babyID: UUID
    private let modelContext: ModelContext

    init(babyID: UUID, modelContext: ModelContext) {
        self.babyID = babyID
        self.modelContext = modelContext
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let rangeStart = selectedRange.startDate
        let now = Date()

        do {
            try loadFeedInsights(from: rangeStart, to: now)
            try loadSleepInsights(from: rangeStart, to: now)
            try loadDiaperInsights(from: rangeStart, to: now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Feed

    private func loadFeedInsights(from start: Date, to end: Date) throws {
        let feeds = try modelContext.fetch(FetchDescriptor<FeedEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.timestamp >= start && $0.timestamp <= end },
            sortBy: [SortDescriptor(\.timestamp)]
        ))

        // Group by day
        let calendar = Calendar.current
        var byDay: [Date: [FeedEntry]] = [:]
        for feed in feeds {
            let day = calendar.startOfDay(for: feed.timestamp)
            byDay[day, default: []].append(feed)
        }

        feedDailyData = byDay.map { date, entries in
            let totalMl = entries.compactMap(\.volumeMl).reduce(0, +)
            let breastMins = entries.filter { $0.feedType == .breast }
                .map { $0.totalDurationSeconds / 60 }.reduce(0, +)
            return DailyFeedPoint(date: date, feedCount: entries.count,
                                  totalVolumeMl: totalMl, breastMinutes: breastMins)
        }.sorted { $0.date < $1.date }

        totalFeedsThisWeek = feeds.count

        // Average interval between feeds
        if feeds.count > 1 {
            let intervals = zip(feeds, feeds.dropFirst()).map { b, a in
                a.timestamp.timeIntervalSince(b.timestamp) / 60
            }
            avgFeedIntervalMinutes = intervals.reduce(0, +) / Double(intervals.count)
        }
    }

    // MARK: - Sleep

    private func loadSleepInsights(from start: Date, to end: Date) throws {
        let sleeps = try modelContext.fetch(FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.startTime >= start && $0.startTime <= end },
            sortBy: [SortDescriptor(\.startTime)]
        ))

        let completed = sleeps.filter { $0.endTime != nil }
        let calendar = Calendar.current
        var byDay: [Date: (nap: Double, night: Double)] = [:]

        for sleep in completed {
            guard let dur = sleep.durationSeconds else { continue }
            let day = calendar.startOfDay(for: sleep.startTime)
            var current = byDay[day] ?? (0, 0)
            if sleep.sleepType == .nap {
                current.nap += dur / 60
            } else {
                current.night += dur / 60
            }
            byDay[day] = current
        }

        sleepDailyData = byDay.map { date, durations in
            DailySleepPoint(date: date, napMinutes: durations.nap, nightMinutes: durations.night)
        }.sorted { $0.date < $1.date }

        let nightSleeps = completed.filter { $0.sleepType == .nighttime }
            .compactMap(\.durationSeconds)
        avgNightSleepMinutes = nightSleeps.isEmpty ? 0 : nightSleeps.reduce(0, +) / Double(nightSleeps.count) / 60

        longestSleepStretchMinutes = (completed.compactMap(\.durationSeconds).max() ?? 0) / 60
    }

    // MARK: - Diapers

    private func loadDiaperInsights(from start: Date, to end: Date) throws {
        let diapers = try modelContext.fetch(FetchDescriptor<DiaperEntry>(
            predicate: #Predicate { $0.babyID == babyID && $0.timestamp >= start && $0.timestamp <= end },
            sortBy: [SortDescriptor(\.timestamp)]
        ))

        let calendar = Calendar.current
        var byDay: [Date: (wet: Int, dirty: Int)] = [:]
        for d in diapers {
            let day = calendar.startOfDay(for: d.timestamp)
            var counts = byDay[day] ?? (0, 0)
            switch d.diaperType {
            case .wet:   counts.wet += 1
            case .dirty: counts.dirty += 1
            case .both:  counts.wet += 1; counts.dirty += 1
            case .dry:   break
            }
            byDay[day] = counts
        }

        diaperDailyData = byDay.map { date, counts in
            DailyDiaperPoint(date: date, wetCount: counts.wet, dirtyCount: counts.dirty)
        }.sorted { $0.date < $1.date }

        avgDiapersPerDay = diapers.isEmpty ? 0 : Double(diapers.count) / max(1, Double(selectedRange.days))
    }

    // MARK: - Formatted stat helpers

    var avgIntervalLabel: String {
        let m = Int(avgFeedIntervalMinutes)
        if m == 0 { return "—" }
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    var avgNightSleepLabel: String {
        let m = Int(avgNightSleepMinutes)
        if m == 0 { return "—" }
        return "\(m / 60)h \(m % 60)m"
    }

    var longestStretchLabel: String {
        let m = Int(longestSleepStretchMinutes)
        if m == 0 { return "—" }
        return "\(m / 60)h \(m % 60)m"
    }
}

// MARK: - Chart data points

struct DailyFeedPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let feedCount: Int
    let totalVolumeMl: Double
    let breastMinutes: Double
}

struct DailySleepPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let napMinutes: Double
    let nightMinutes: Double
    var totalMinutes: Double { napMinutes + nightMinutes }
}

struct DailyDiaperPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let wetCount: Int
    let dirtyCount: Int
    var totalCount: Int { wetCount + dirtyCount }
}

// MARK: - Range

enum InsightRange: String, CaseIterable {
    case week   = "7D"
    case month  = "30D"
    case quarter = "90D"

    var days: Int {
        switch self { case .week: 7; case .month: 30; case .quarter: 90 }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    var label: String {
        switch self { case .week: "Week"; case .month: "Month"; case .quarter: "3 Months" }
    }
}
