import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ─── Notification ID namespaces ───────────────────────────────────────────────
// Each category owns a range of integer IDs to avoid collisions.
// Feed reminders:        1 000 000 – 1 999 999
// Diaper reminders:      2 000 000 – 2 999 999
// Medication reminders:  3 000 000 – 3 999 999
// Vaccine reminders:     4 000 000 – 4 999 999
// Appointment reminders: 5 000 000 – 5 999 999

const _kChannelFeed = 'baby_tracker_feed';
const _kChannelDiaper = 'baby_tracker_diaper';
const _kChannelMedication = 'baby_tracker_medication';
const _kChannelVaccine = 'baby_tracker_vaccine';
const _kChannelAppointment = 'baby_tracker_appointment';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once from main() before runApp().
  Future<void> initialize() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    await registerAndroidChannel(
      id: _kChannelFeed,
      name: 'Feed Reminders',
      description: 'Reminders to log or schedule a feeding.',
    );
    await registerAndroidChannel(
      id: _kChannelDiaper,
      name: 'Diaper Reminders',
      description: 'Reminders to check and change the diaper.',
    );
    await registerAndroidChannel(
      id: _kChannelMedication,
      name: 'Medication Reminders',
      description: 'Reminders for scheduled medication doses.',
      importance: Importance.high,
    );
    await registerAndroidChannel(
      id: _kChannelVaccine,
      name: 'Vaccine Reminders',
      description: 'Upcoming vaccine appointment reminders.',
    );
    await registerAndroidChannel(
      id: _kChannelAppointment,
      name: 'Appointment Reminders',
      description: 'Upcoming doctor appointment reminders.',
    );

    _initialised = true;
  }

  // ── Permission ────────────────────────────────────────────────────────────

  /// Request notification permissions from the OS.
  /// Returns true if granted (iOS/macOS); Android 13+ uses the manifest.
  Future<bool> requestPermission() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final mac = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    return (ios ?? false) || (mac ?? false) || (android ?? false);
  }

  /// Register an Android notification channel. Safe to call multiple times.
  Future<void> registerAndroidChannel({
    required String id,
    required String name,
    required String description,
    Importance importance = Importance.defaultImportance,
  }) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            id,
            name,
            description: description,
            importance: importance,
          ),
        );
  }

  // ── Feed reminders ────────────────────────────────────────────────────────

  /// Schedule a single feed reminder at [scheduledAt].
  /// [babyId] is used to derive a stable notification ID so repeat calls
  /// for the same baby overwrite the previous reminder.
  Future<void> scheduleFeedReminder({
    required String babyId,
    required String babyName,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    await _ensureInit();
    final id = _feedId(babyId);
    final tzTime = _toTZ(scheduledAt);

    await _plugin.zonedSchedule(
      id,
      'Time to feed $babyName',
      notes ?? 'Tap to log a feeding.',
      tzTime,
      _notifDetails(channelId: _kChannelFeed),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all feed reminders for [babyId].
  Future<void> cancelFeedReminder(String babyId) async {
    await _plugin.cancel(_feedId(babyId));
  }

  // ── Diaper reminders ──────────────────────────────────────────────────────

  /// Schedule a diaper-check reminder at [scheduledAt].
  Future<void> scheduleDiaperReminder({
    required String babyId,
    required String babyName,
    required DateTime scheduledAt,
  }) async {
    await _ensureInit();
    final id = _diaperId(babyId);
    final tzTime = _toTZ(scheduledAt);

    await _plugin.zonedSchedule(
      id,
      'Diaper check for $babyName',
      'Time to check the diaper!',
      tzTime,
      _notifDetails(channelId: _kChannelDiaper),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all diaper reminders for [babyId].
  Future<void> cancelDiaperReminder(String babyId) async {
    await _plugin.cancel(_diaperId(babyId));
  }

  // ── Medication reminders ──────────────────────────────────────────────────

  /// Schedule a medication-dose reminder.
  /// [medicationId] is used for the stable notification ID.
  /// Each dose fires a separate notification; pass a unique [doseIndex] to
  /// differentiate multiple upcoming doses for the same medication.
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String medicationName,
    required String babyName,
    required DateTime scheduledAt,
    int doseIndex = 0,
    String? notes,
  }) async {
    await _ensureInit();
    final id = _medicationId(medicationId, doseIndex);
    final tzTime = _toTZ(scheduledAt);

    await _plugin.zonedSchedule(
      id,
      '$medicationName due for $babyName',
      notes ?? 'Tap to log the dose.',
      tzTime,
      _notifDetails(
        channelId: _kChannelMedication,
        importance: Importance.high,
        priority: Priority.high,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all scheduled notifications for a specific medication.
  /// Cancels up to [maxDoses] upcoming dose notifications.
  Future<void> cancelMedicationReminders(
    String medicationId, {
    int maxDoses = 30,
  }) async {
    for (var i = 0; i < maxDoses; i++) {
      await _plugin.cancel(_medicationId(medicationId, i));
    }
  }

  // ── Vaccine reminders ─────────────────────────────────────────────────────

  /// Schedule a vaccine reminder [daysBefore] days ahead of [vaccineDate].
  Future<void> scheduleVaccineReminder({
    required String vaccineId,
    required String vaccineName,
    required String babyName,
    required DateTime vaccineDate,
    int daysBefore = 7,
  }) async {
    await _ensureInit();
    final id = _vaccineId(vaccineId);
    final reminderDate = vaccineDate.subtract(Duration(days: daysBefore));
    if (reminderDate.isBefore(DateTime.now())) return;
    final tzTime = _toTZ(reminderDate);

    await _plugin.zonedSchedule(
      id,
      '$vaccineName coming up for $babyName',
      'Vaccine appointment in $daysBefore days.',
      tzTime,
      _notifDetails(channelId: _kChannelVaccine),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel vaccine reminder for [vaccineId].
  Future<void> cancelVaccineReminder(String vaccineId) async {
    await _plugin.cancel(_vaccineId(vaccineId));
  }

  // ── Appointment reminders ─────────────────────────────────────────────────

  /// Schedule up to two appointment reminders: one day before and one hour
  /// before [appointmentTime].
  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String appointmentType,
    required String babyName,
    required DateTime appointmentTime,
    String? providerName,
  }) async {
    await _ensureInit();
    final subtitle =
        providerName != null ? 'with $providerName' : 'for $babyName';

    // 24-hour reminder
    final oneDayBefore = appointmentTime.subtract(const Duration(hours: 24));
    if (oneDayBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _appointmentId(appointmentId, 0),
        '$appointmentType tomorrow',
        'Appointment $subtitle is in 24 hours.',
        _toTZ(oneDayBefore),
        _notifDetails(channelId: _kChannelAppointment),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 1-hour reminder
    final oneHourBefore = appointmentTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _appointmentId(appointmentId, 1),
        '$appointmentType in 1 hour',
        'Appointment $subtitle starts soon.',
        _toTZ(oneHourBefore),
        _notifDetails(
          channelId: _kChannelAppointment,
          importance: Importance.high,
          priority: Priority.high,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel both appointment reminders for [appointmentId].
  Future<void> cancelAppointmentReminders(String appointmentId) async {
    await _plugin.cancel(_appointmentId(appointmentId, 0));
    await _plugin.cancel(_appointmentId(appointmentId, 1));
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Pending list ──────────────────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> pendingNotifications() {
    return _plugin.pendingNotificationRequests();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (!_initialised) await initialize();
  }

  tz.TZDateTime _toTZ(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  NotificationDetails _notifDetails({
    required String channelId,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId, // name shown in settings if channel missing
        importance: importance,
        priority: priority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ── ID derivation ─────────────────────────────────────────────────────────
  // Derive stable integer IDs from string identifiers using a simple hash.
  // Each category owns a separate range to guarantee no cross-category collision.

  int _stableId(String key, int rangeStart) {
    // Fold the hashCode into a positive 6-digit number within the category range.
    final hash = key.hashCode.abs() % 999999;
    return rangeStart + hash;
  }

  int _feedId(String babyId) => _stableId(babyId, 1000000);
  int _diaperId(String babyId) => _stableId(babyId, 2000000);
  int _medicationId(String medicationId, int doseIndex) =>
      _stableId('$medicationId:$doseIndex', 3000000);
  int _vaccineId(String vaccineId) => _stableId(vaccineId, 4000000);
  int _appointmentId(String appointmentId, int slot) =>
      _stableId('$appointmentId:$slot', 5000000);
}

// ── Notification tap handlers ─────────────────────────────────────────────────

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // Handle background taps (e.g. route to relevant screen) here.
  // Because this runs in a background isolate, only lightweight work is safe.
}

void _onNotificationResponse(NotificationResponse response) {
  // Handle foreground taps. Navigation can be triggered from here via a
  // global navigator key or Riverpod container if needed.
}
