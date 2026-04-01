import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Displayed State

    private(set) var lastFeed: FeedEntry?
    private(set) var lastSleep: SleepEntry?
    private(set) var lastDiaper: DiaperEntry?
    private(set) var ongoingSleep: SleepEntry?

    // Today's totals
    private(set) var todayFeedCount: Int = 0
    private(set) var todayFeedVolumeMl: Double = 0
    private(set) var todaySleepMinutes: Int = 0
    private(set) var todayDiaperCount: Int = 0

    // Wake window (minutes awake since last woke up)
    private(set) var minutesAwake: Double = 0
    var wakeWindowGoalMinutes: Double = 90   // user-configurable per-baby eventually

    // Ticks every second — views bind elapsed timers to this
    private(set) var now: Date = Date()

    // Quick-log sheet routing
    var activeSheet: HomeSheet?

    // Error display
    var errorMessage: String?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let entryRepo: EntryRepository
    private let babyRepo: BabyRepository
    let babyID: UUID

    // MARK: - Timer

    private var tickTimer: Timer?

    // MARK: - Init

    init(babyID: UUID, modelContext: ModelContext, entryRepo: EntryRepository, babyRepo: BabyRepository) {
        self.babyID = babyID
        self.modelContext = modelContext
        self.entryRepo = entryRepo
        self.babyRepo = babyRepo
    }

    // MARK: - Lifecycle

    func onAppear() {
        startTimer()
        reload()
    }

    func onDisappear() {
        stopTimer()
    }

    // MARK: - Load data

    func reload() {
        do {
            lastFeed    = try entryRepo.lastFeed(for: babyID)
            lastSleep   = try entryRepo.lastSleep(for: babyID)
            lastDiaper  = try entryRepo.lastDiaper(for: babyID)
            ongoingSleep = try entryRepo.ongoingSleep(for: babyID)
            try loadTodayTotals()
            updateWakeWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadTodayTotals() throws {
        let todayStart = Calendar.current.startOfDay(for: Date())

        let feeds = try entryRepo.feedEntries(for: babyID)
        let todayFeeds = feeds.filter { $0.timestamp >= todayStart }
        todayFeedCount = todayFeeds.count
        todayFeedVolumeMl = todayFeeds.compactMap(\.volumeMl).reduce(0, +)

        let sleeps = try entryRepo.sleepEntries(for: babyID)
        let todaySleeps = sleeps.filter { $0.startTime >= todayStart }
        todaySleepMinutes = Int(todaySleeps.compactMap(\.durationSeconds).reduce(0, +) / 60)

        let diapers = try entryRepo.diaperEntries(for: babyID)
        todayDiaperCount = diapers.filter { $0.timestamp >= todayStart }.count
    }

    private func updateWakeWindow() {
        // Wake window starts from when the last sleep ended (or birth if no sleep)
        guard let lastSleep else {
            minutesAwake = 0
            return
        }
        if let end = lastSleep.endTime {
            minutesAwake = Date().timeIntervalSince(end) / 60
        } else {
            // Currently sleeping
            minutesAwake = 0
        }
    }

    // MARK: - Timer

    private func startTimer() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
                self?.updateWakeWindow()
            }
        }
    }

    private func stopTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    // MARK: - Quick actions

    func stopOngoingSleep() {
        guard let ongoing = ongoingSleep else { return }
        ongoing.endTime = Date()
        do {
            try entryRepo.updateSleep(ongoing)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Formatted elapsed strings

    func elapsedString(since date: Date?) -> String {
        guard let date else { return "—" }
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h ago" }
        return "\(hours)h \(mins)m ago"
    }

    var lastFeedElapsed: String { elapsedString(since: lastFeed?.timestamp) }
    var lastSleepElapsed: String { elapsedString(since: lastSleep?.endTime ?? lastSleep?.startTime) }
    var lastDiaperElapsed: String { elapsedString(since: lastDiaper?.timestamp) }

    var ongoingSleepDuration: String {
        guard let start = ongoingSleep?.startTime else { return "" }
        let seconds = Int(now.timeIntervalSince(start))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    // Wake window progress 0.0 – 1.0 (can exceed 1.0 when overdue)
    var wakeWindowProgress: Double {
        guard wakeWindowGoalMinutes > 0 else { return 0 }
        return min(minutesAwake / wakeWindowGoalMinutes, 1.0)
    }

    var wakeWindowLabel: String {
        if ongoingSleep != nil { return "Sleeping now" }
        if minutesAwake == 0 { return "No sleep logged yet" }
        let m = Int(minutesAwake)
        if m < 60 { return "Awake \(m)m" }
        let h = m / 60; let rem = m % 60
        return rem == 0 ? "Awake \(h)h" : "Awake \(h)h \(rem)m"
    }

    var wakeWindowColor: WakeWindowColor {
        if ongoingSleep != nil { return .sleeping }
        let ratio = minutesAwake / wakeWindowGoalMinutes
        if ratio < 0.6 { return .early }
        if ratio < 0.85 { return .ready }
        return .overdue
    }

    enum WakeWindowColor { case sleeping, early, ready, overdue }
}

// MARK: - Sheet routing

enum HomeSheet: Identifiable {
    case feed, sleep, diaper, other
    var id: String { "\(self)" }
}
