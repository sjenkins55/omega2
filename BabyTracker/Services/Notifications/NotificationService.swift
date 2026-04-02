import Foundation
import UserNotifications
import SwiftData

/// Centralizes all local notification scheduling for the app.
///
/// Call sites:
///   - After logging a feed → reschedule feed reminder
///   - After logging a diaper → reschedule diaper reminder
///   - When a medication is created/edited → schedule dose reminders
///   - On app foreground → refresh all reminders for all active babies
///
/// All notifications are local-first. Remote push (via Supabase Edge Function)
/// is only used for cross-caregiver events ("Dad just fed Emma") — not covered here.

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Feed reminder
    // Fires X minutes after the last feed ended (or started for breast).

    func scheduleFeedReminder(babyID: UUID, babyName: String, lastFeedAt: Date, intervalMinutes: Int) async {
        let id = notificationID(.feedReminder, babyID: babyID)
        await center.removePendingNotificationRequests(withIdentifiers: [id])

        guard intervalMinutes > 0 else { return }
        guard await isAuthorized else { return }

        let fireDate = lastFeedAt.addingTimeInterval(Double(intervalMinutes) * 60)
        guard fireDate > Date() else { return }  // already overdue — don't schedule

        let content = UNMutableNotificationContent()
        content.title = "\(babyName) may be hungry"
        content.body = "It's been \(intervalMinutes / 60)h \(intervalMinutes % 60)m since the last feed."
        content.sound = .default
        content.badge = 1
        content.userInfo = ["babyID": babyID.uuidString, "type": "feedReminder"]
        content.categoryIdentifier = NotificationCategory.feedReminder

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow, repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelFeedReminder(babyID: UUID) async {
        await center.removePendingNotificationRequests(
            withIdentifiers: [notificationID(.feedReminder, babyID: babyID)]
        )
    }

    // MARK: - Diaper reminder

    func scheduleDiaperReminder(babyID: UUID, babyName: String, lastChangeAt: Date, intervalMinutes: Int) async {
        let id = notificationID(.diaperReminder, babyID: babyID)
        await center.removePendingNotificationRequests(withIdentifiers: [id])

        guard intervalMinutes > 0, await isAuthorized else { return }

        let fireDate = lastChangeAt.addingTimeInterval(Double(intervalMinutes) * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to check \(babyName)'s diaper"
        content.body = "\(intervalMinutes / 60)h \(intervalMinutes % 60)m since last change."
        content.sound = .default
        content.userInfo = ["babyID": babyID.uuidString, "type": "diaperReminder"]
        content.categoryIdentifier = NotificationCategory.diaperReminder

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow, repeats: false
        )
        try? await center.add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

    // MARK: - Medication reminders

    /// Schedule repeating dose reminders for a scheduled medication.
    func scheduleMedicationReminders(medication: Medication, babyName: String) async {
        guard medication.isScheduled, let freqHours = medication.frequencyHours else { return }
        guard await isAuthorized else { return }

        // Cancel any existing reminders for this medication
        await cancelMedicationReminders(medicationID: medication.id)

        let endDate = medication.endDate ?? medication.startDate.addingTimeInterval(30 * 24 * 3600)
        guard endDate > Date() else { return }

        let intervalSeconds = freqHours * 3600
        var fireDate = max(medication.startDate, Date()).addingTimeInterval(intervalSeconds)
        var index = 0

        // Schedule up to 64 future doses (iOS limit is 64 pending notifications total)
        while fireDate <= endDate && index < 20 {
            let id = "\(NotificationCategory.medication)-\(medication.id)-\(index)"
            let content = UNMutableNotificationContent()
            content.title = "\(medication.name) dose for \(babyName)"
            content.body = "\(medication.dose)\(medication.doseUnit.rawValue) · \(medication.route.rawValue)"
            content.sound = .default
            content.userInfo = ["medicationID": medication.id.uuidString, "babyName": babyName]
            content.categoryIdentifier = NotificationCategory.medication

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: fireDate.timeIntervalSinceNow, repeats: false
            )
            try? await center.add(
                UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            )
            fireDate = fireDate.addingTimeInterval(intervalSeconds)
            index += 1
        }
    }

    func cancelMedicationReminders(medicationID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { $0.identifier.hasPrefix("\(NotificationCategory.medication)-\(medicationID)") }
            .map(\.identifier)
        await center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Vaccine reminders

    func scheduleVaccineReminder(vaccineID: UUID, vaccineName: String, babyName: String, dueDate: Date) async {
        guard await isAuthorized else { return }
        let intervals: [(days: Int, label: String)] = [(30, "1 month"), (7, "1 week"), (1, "tomorrow")]

        for (days, label) in intervals {
            let fireDate = dueDate.addingTimeInterval(-Double(days) * 86400)
            guard fireDate > Date() else { continue }

            let id = "\(NotificationCategory.vaccine)-\(vaccineID)-\(days)"
            let content = UNMutableNotificationContent()
            content.title = "\(vaccineName) due \(label)"
            content.body = "\(babyName) is due for \(vaccineName) in \(label)."
            content.sound = .default
            content.userInfo = ["vaccineID": vaccineID.uuidString]
            content.categoryIdentifier = NotificationCategory.vaccine

            try? await center.add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: fireDate.timeIntervalSinceNow, repeats: false
                )
            ))
        }
    }

    // MARK: - Appointment reminder

    func scheduleAppointmentReminder(appointmentID: UUID, type: String, babyName: String, scheduledAt: Date) async {
        guard await isAuthorized else { return }

        for (days, label) in [(1, "tomorrow"), (0, "today")] {
            let fireDate: Date
            if days == 0 {
                // Fire at 8am on the day of the appointment
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: scheduledAt)
                comps.hour = 8; comps.minute = 0
                fireDate = Calendar.current.date(from: comps) ?? scheduledAt
            } else {
                fireDate = scheduledAt.addingTimeInterval(-Double(days) * 86400)
            }
            guard fireDate > Date() else { continue }

            let id = "\(NotificationCategory.appointment)-\(appointmentID)-\(days)"
            let content = UNMutableNotificationContent()
            content.title = "\(babyName)'s \(type) appointment is \(label)"
            content.body = DateFormatter.localizedString(from: scheduledAt, dateStyle: .none, timeStyle: .short)
            content.sound = .default

            try? await center.add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: fireDate.timeIntervalSinceNow, repeats: false
                )
            ))
        }
    }

    // MARK: - Daily summary

    func scheduleDailySummary(babyName: String, hour: Int = 20, minute: Int = 0) async {
        guard await isAuthorized else { return }
        await center.removePendingNotificationRequests(withIdentifiers: [NotificationCategory.dailySummary])

        let content = UNMutableNotificationContent()
        content.title = "\(babyName)'s daily summary"
        content.body = "Tap to review today's feeds, sleep, and diapers."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailySummary

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        try? await center.add(UNNotificationRequest(
            identifier: NotificationCategory.dailySummary,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        ))
    }

    func cancelDailySummary() async {
        await center.removePendingNotificationRequests(withIdentifiers: [NotificationCategory.dailySummary])
    }

    // MARK: - Cancel appointment reminders

    func cancelAppointmentReminders(appointmentID: UUID) {
        let ids = [
            "\(NotificationCategory.appointment)-\(appointmentID)-0",
            "\(NotificationCategory.appointment)-\(appointmentID)-1",
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Cancel all for a baby

    func cancelAllReminders(for babyID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { ($0.content.userInfo["babyID"] as? String) == babyID.uuidString }
            .map(\.identifier)
        await center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Register notification categories (call at app launch)

    func registerCategories() {
        let logFeedAction = UNNotificationAction(
            identifier: "LOG_FEED", title: "Log Feed", options: [.foreground]
        )
        let logDiaperAction = UNNotificationAction(
            identifier: "LOG_DIAPER", title: "Log Diaper", options: [.foreground]
        )
        let doseGivenAction = UNNotificationAction(
            identifier: "DOSE_GIVEN", title: "Given ✓", options: []
        )
        let doseSkippedAction = UNNotificationAction(
            identifier: "DOSE_SKIP", title: "Skip", options: [.destructive]
        )

        let feedCategory = UNNotificationCategory(
            identifier: NotificationCategory.feedReminder,
            actions: [logFeedAction],
            intentIdentifiers: []
        )
        let diaperCategory = UNNotificationCategory(
            identifier: NotificationCategory.diaperReminder,
            actions: [logDiaperAction],
            intentIdentifiers: []
        )
        let medCategory = UNNotificationCategory(
            identifier: NotificationCategory.medication,
            actions: [doseGivenAction, doseSkippedAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([feedCategory, diaperCategory, medCategory])
    }

    // MARK: - Helpers

    private enum NotificationType: String {
        case feedReminder, diaperReminder
    }

    private func notificationID(_ type: NotificationType, babyID: UUID) -> String {
        "\(type.rawValue)-\(babyID.uuidString)"
    }
}

// MARK: - Category identifiers

enum NotificationCategory {
    static let feedReminder   = "FEED_REMINDER"
    static let diaperReminder = "DIAPER_REMINDER"
    static let medication     = "MEDICATION"
    static let vaccine        = "VACCINE"
    static let appointment    = "APPOINTMENT"
    static let dailySummary   = "DAILY_SUMMARY"
}
