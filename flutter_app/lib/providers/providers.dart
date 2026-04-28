import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';

export '../services/auth_service.dart' show AuthState, AuthNotifier;
export '../services/sync_manager.dart' show SyncState, SyncManager;
export '../services/subscription_service.dart'
    show SubscriptionTier, SubscriptionNotifier;

// ─── Singleton services ───────────────────────────────────────────────────────

/// The single Drift database instance. Closed when the provider is disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Supabase wrapper (stubbed until credentials are set).
final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService());

/// flutter_local_notifications wrapper.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

// ─── StateNotifier providers ──────────────────────────────────────────────────

/// Authentication state: loading → anonymous | authenticated.
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(databaseProvider),
    ref.watch(supabaseServiceProvider),
  );
});

/// Offline sync queue with online/offline awareness via connectivity_plus.
final syncManagerProvider =
    StateNotifierProvider<SyncManager, SyncState>((ref) {
  return SyncManager(ref.watch(supabaseServiceProvider));
});

/// In-app subscription tier (free / premium).
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionTier>((ref) {
  return SubscriptionNotifier();
});

// ─── App-level state ──────────────────────────────────────────────────────────

/// Persisted in main.dart from SharedPreferences before ProviderScope mounts.
final hasCompletedOnboardingProvider = StateProvider<bool>((_) => false);

/// The baby currently being viewed. Defaults to the first baby in the list.
final activeBabyIdProvider = StateProvider<String?>((_) => null);

// ─── Database stream providers ────────────────────────────────────────────────

/// Live list of all non-archived babies, ordered by creation time.
final babiesStreamProvider = StreamProvider<List<BabiesData>>((ref) {
  return ref.watch(databaseProvider).watchBabies();
});

/// The active baby row, or the first baby if no explicit selection has been made.
final activeBabyProvider = Provider<BabiesData?>((ref) {
  final id = ref.watch(activeBabyIdProvider);
  final babies = ref.watch(babiesStreamProvider).valueOrNull ?? [];
  if (babies.isEmpty) return null;
  if (id == null) return babies.first;
  return babies.firstWhere(
    (b) => b.id == id,
    orElse: () => babies.first,
  );
});

/// Live feed entries for the active baby, newest first.
final feedEntriesProvider = StreamProvider<List<FeedEntriesData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchFeedEntries(babyId);
});

/// Live sleep entries for the active baby, newest first.
final sleepEntriesProvider = StreamProvider<List<SleepEntriesData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchSleepEntries(babyId);
});

/// Live diaper entries for the active baby, newest first.
final diaperEntriesProvider = StreamProvider<List<DiaperEntriesData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchDiaperEntries(babyId);
});

/// Live medications for the active baby, alphabetically ordered.
final medicationsProvider = StreamProvider<List<MedicationsData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMedications(babyId);
});

/// Live illnesses for the active baby, most recent onset first.
final illnessesProvider = StreamProvider<List<IllnessesData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchIllnesses(babyId);
});

/// Live appointments for the active baby, ordered by scheduled time ascending.
final appointmentsProvider = StreamProvider<List<AppointmentsData>>((ref) {
  final babyId = ref.watch(activeBabyIdProvider);
  if (babyId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchAppointments(babyId);
});

/// The caregiver associated with this device (one-shot future).
final currentCaregiverProvider = FutureProvider<CaregiversData?>((ref) {
  return ref.watch(databaseProvider).getCurrentCaregiver();
});

/// Live stream of the caregiver for this device (rebuilds on change).
final currentCaregiverStreamProvider = StreamProvider<CaregiversData?>((ref) {
  return ref.watch(databaseProvider).watchCurrentCaregiver();
});
