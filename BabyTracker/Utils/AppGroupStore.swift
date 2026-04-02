import Foundation
import WidgetKit

/// Shared data store between the main app and Widget/Live Activity extensions.
/// Uses an App Group so all targets can read/write the same UserDefaults.
///
/// Xcode setup required:
///   1. Add App Group capability to BabyTracker target:
///      "group.com.yourcompany.babytracker"
///   2. Add the same App Group to BabyTrackerWidget target
///   3. Replace the identifier below with your actual App Group ID

struct AppGroupStore {

    static let groupID = "group.com.yourcompany.babytracker"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: - Keys

    private enum Key {
        static let widgetSnapshot = "widgetSnapshot"
        static let activeNursingSession = "activeNursingSession"
    }

    // MARK: - Widget Snapshot
    // Written after every feed/sleep/diaper log so the widget always has fresh data.

    static func saveWidgetSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.widgetSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadWidgetSnapshot() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Key.widgetSnapshot) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // MARK: - Active nursing session (for Live Activity handoff)

    static func saveNursingSession(_ session: NursingSession?) {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Key.activeNursingSession)
        } else {
            defaults.removeObject(forKey: Key.activeNursingSession)
        }
    }

    static func loadNursingSession() -> NursingSession? {
        guard let data = defaults.data(forKey: Key.activeNursingSession) else { return nil }
        return try? JSONDecoder().decode(NursingSession.self, from: data)
    }
}

// MARK: - Shared data models

/// Lightweight snapshot written after each log — read by widgets.
struct WidgetSnapshot: Codable {
    var babyName: String
    var babyID: String

    // Last feed
    var lastFeedAt: Date?
    var lastFeedType: String?       // "Breast", "Bottle 120ml", etc.

    // Last sleep
    var lastSleepEndAt: Date?
    var sleepIsOngoing: Bool
    var ongoingSleepStartedAt: Date?

    // Last diaper
    var lastDiaperAt: Date?
    var lastDiaperType: String?

    // Today's totals
    var todayFeedCount: Int
    var todaySleepMinutes: Int
    var todayDiaperCount: Int

    static let placeholder = WidgetSnapshot(
        babyName: "Emma",
        babyID: "",
        lastFeedAt: Date().addingTimeInterval(-5400),
        lastFeedType: "Breast · 12m",
        lastSleepEndAt: Date().addingTimeInterval(-7200),
        sleepIsOngoing: false,
        ongoingSleepStartedAt: nil,
        lastDiaperAt: Date().addingTimeInterval(-3600),
        lastDiaperType: "Wet",
        todayFeedCount: 6,
        todaySleepMinutes: 240,
        todayDiaperCount: 5
    )
}

/// Describes an in-progress nursing session for the Live Activity.
struct NursingSession: Codable {
    var babyName: String
    var startedAt: Date
    var activeSide: String       // "left", "right", or "both"
    var leftSeconds: Double
    var rightSeconds: Double
    var sideStartedAt: Date?
}

// MARK: - Convenience: update snapshot after any log

extension AppGroupStore {

    /// Call after every FeedEntry, SleepEntry, or DiaperEntry save.
    /// Reads fresh data directly from the App Group — no model context needed.
    static func refreshSnapshot(
        babyName: String, babyID: String,
        lastFeed: (date: Date, detail: String)?,
        lastSleep: (endDate: Date?, isOngoing: Bool, startedAt: Date?)?,
        lastDiaper: (date: Date, type: String)?,
        todayFeeds: Int, todaySleepMinutes: Int, todayDiapers: Int
    ) {
        let snapshot = WidgetSnapshot(
            babyName: babyName,
            babyID: babyID,
            lastFeedAt: lastFeed?.date,
            lastFeedType: lastFeed?.detail,
            lastSleepEndAt: lastSleep?.endDate,
            sleepIsOngoing: lastSleep?.isOngoing ?? false,
            ongoingSleepStartedAt: lastSleep?.startedAt,
            lastDiaperAt: lastDiaper?.date,
            lastDiaperType: lastDiaper?.type,
            todayFeedCount: todayFeeds,
            todaySleepMinutes: todaySleepMinutes,
            todayDiaperCount: todayDiapers
        )
        saveWidgetSnapshot(snapshot)
    }
}
