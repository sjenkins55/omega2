import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct BabyTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyTrackerSmallWidget()
        BabyTrackerMediumWidget()
        BabyTrackerLockScreenWidget()
    }
}

// MARK: - Timeline Provider

struct BabyTrackerTimelineProvider: TimelineProvider {

    typealias Entry = BabyWidgetEntry

    func placeholder(in context: Context) -> BabyWidgetEntry {
        BabyWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyWidgetEntry) -> Void) {
        let snapshot = AppGroupStore.loadWidgetSnapshot() ?? .placeholder
        completion(BabyWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyWidgetEntry>) -> Void) {
        let snapshot = AppGroupStore.loadWidgetSnapshot() ?? .placeholder
        let now = Date()

        // Refresh every 5 minutes so elapsed timers stay reasonably accurate.
        // The main app calls WidgetCenter.reloadAllTimelines() after every log
        // for instant updates.
        let entries = (0..<6).map { i in
            BabyWidgetEntry(date: now.addingTimeInterval(Double(i) * 300), snapshot: snapshot)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct BabyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Small Widget

struct BabyTrackerSmallWidget: Widget {
    let kind = "BabyTrackerSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyTrackerTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Baby Status")
        .description("Last feed, sleep, and diaper at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium Widget

struct BabyTrackerMediumWidget: Widget {
    let kind = "BabyTrackerMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyTrackerTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Baby Dashboard")
        .description("Today's feed, sleep, and diaper summary.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Lock Screen Widget

struct BabyTrackerLockScreenWidget: Widget {
    let kind = "BabyTrackerLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyTrackerTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Feed")
        .description("Time since last feed on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: BabyWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Baby name header
            Text(entry.snapshot.babyName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            // Last feed
            WidgetStatRow(
                icon: "drop.fill", color: .blue,
                label: "Fed",
                value: elapsedString(since: entry.snapshot.lastFeedAt, at: entry.date)
            )

            // Sleep
            WidgetStatRow(
                icon: "moon.fill", color: .indigo,
                label: entry.snapshot.sleepIsOngoing ? "Sleeping" : "Slept",
                value: entry.snapshot.sleepIsOngoing
                    ? elapsedString(since: entry.snapshot.ongoingSleepStartedAt, at: entry.date)
                    : elapsedString(since: entry.snapshot.lastSleepEndAt, at: entry.date)
            )

            // Diaper
            WidgetStatRow(
                icon: "drop.triangle.fill", color: .orange,
                label: "Diaper",
                value: elapsedString(since: entry.snapshot.lastDiaperAt, at: entry.date)
            )
        }
        .padding(12)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: BabyWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: status column
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.snapshot.babyName)
                    .font(.subheadline.weight(.bold))

                WidgetStatRow(icon: "drop.fill", color: .blue,
                              label: "Last fed",
                              value: elapsedString(since: entry.snapshot.lastFeedAt, at: entry.date))
                WidgetStatRow(icon: "moon.fill", color: .indigo,
                              label: entry.snapshot.sleepIsOngoing ? "Sleeping" : "Last slept",
                              value: entry.snapshot.sleepIsOngoing
                                ? elapsedString(since: entry.snapshot.ongoingSleepStartedAt, at: entry.date)
                                : elapsedString(since: entry.snapshot.lastSleepEndAt, at: entry.date))
                WidgetStatRow(icon: "drop.triangle.fill", color: .orange,
                              label: "Diaper",
                              value: elapsedString(since: entry.snapshot.lastDiaperAt, at: entry.date))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.horizontal, 8)

            // Right: today's totals
            VStack(spacing: 10) {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TodayCountBadge(icon: "drop.fill", color: .blue,
                                count: entry.snapshot.todayFeedCount, label: "feeds")
                TodayCountBadge(icon: "moon.fill", color: .indigo,
                                count: entry.snapshot.todaySleepMinutes / 60,
                                label: entry.snapshot.todaySleepMinutes >= 120 ? "hrs sleep" : "hr sleep")
                TodayCountBadge(icon: "drop.triangle.fill", color: .orange,
                                count: entry.snapshot.todayDiaperCount, label: "diapers")
            }
            .frame(width: 90)
        }
        .padding(14)
    }
}

// MARK: - Lock Screen Views

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BabyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 10) {
                Image(systemName: "drop.fill").foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("Last fed").font(.caption2).foregroundStyle(.secondary)
                    Text(elapsedString(since: entry.snapshot.lastFeedAt, at: entry.date))
                        .font(.caption.weight(.semibold))
                }
            }
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "drop.fill").foregroundStyle(.blue)
                Text(compactElapsed(since: entry.snapshot.lastFeedAt, at: entry.date))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        default:
            EmptyView()
        }
    }

    private func compactElapsed(since date: Date?, at now: Date) -> String {
        guard let date else { return "—" }
        let m = Int(now.timeIntervalSince(date) / 60)
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h"
    }
}

// MARK: - Shared widget sub-views

struct WidgetStatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 11))
                .frame(width: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption2.weight(.semibold))
        }
    }
}

struct TodayCountBadge: View {
    let icon: String
    let color: Color
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 10))
            Text("\(count) \(label)").font(.caption2)
        }
    }
}

// MARK: - Elapsed string helper (used in widget — no @State allowed)

private func elapsedString(since date: Date?, at now: Date) -> String {
    guard let date else { return "—" }
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 { return "just now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    let mins = minutes % 60
    return mins == 0 ? "\(hours)h ago" : "\(hours)h \(mins)m ago"
}
