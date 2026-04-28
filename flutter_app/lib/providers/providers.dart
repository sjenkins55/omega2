// ignore_for_file: unused_element
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Placeholder types ────────────────────────────────────────────────────────
// These types represent the real implementations to be wired up separately.
// The UI files import only from this file for all provider references.

// ── Auth ──────────────────────────────────────────────────────────────────────

enum AuthState { loading, anonymous, authenticated }

final authProvider = StateProvider<AuthState>((_) => AuthState.loading);

// ── Onboarding ────────────────────────────────────────────────────────────────

final hasCompletedOnboardingProvider = StateProvider<bool>((_) => false);

// ── Database ──────────────────────────────────────────────────────────────────

// Placeholder – replaced by the real AppDatabase provider in app_database.dart
// final databaseProvider = Provider<AppDatabase>(...);

// ── Sync ──────────────────────────────────────────────────────────────────────

class SyncState {
  final bool isOnline;
  final int pendingCount;

  const SyncState({this.isOnline = false, this.pendingCount = 0});
}

class SyncManager extends StateNotifier<SyncState> {
  SyncManager() : super(const SyncState());

  /// Enqueue a sync operation to be sent to Supabase when online.
  void enqueue(dynamic operation) {
    state = SyncState(
      isOnline: state.isOnline,
      pendingCount: state.pendingCount + 1,
    );
  }
}

final syncManagerProvider =
    StateNotifierProvider<SyncManager, SyncState>((_) => SyncManager());

// ── Subscription ──────────────────────────────────────────────────────────────

enum SubscriptionTier { free, premium }

final subscriptionProvider =
    StateProvider<SubscriptionTier>((_) => SubscriptionTier.free);

// ── Baby data types (Drift row type stand-ins) ────────────────────────────────

class BabiesData {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final bool isPreterm;
  final int? weeksGestation;
  final String? photoUrl;

  const BabiesData({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    this.isPreterm = false,
    this.weeksGestation,
    this.photoUrl,
  });

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - dateOfBirth.year) * 12 + now.month - dateOfBirth.month;
  }

  String get ageLabel {
    final months = ageInMonths;
    final days = DateTime.now().difference(dateOfBirth).inDays;
    if (months < 1) return '${days}d old';
    if (months < 24) return '${months}mo old';
    return '${months ~/ 12}y old';
  }
}

// ── Feed entry data (Drift row type stand-in) ─────────────────────────────────

class FeedEntriesData {
  final String id;
  final String babyId;
  final String caregiverId;
  final DateTime timestamp;
  final String feedType; // breast / bottle / solids / pump
  final int? leftDurationSeconds;
  final int? rightDurationSeconds;
  final double? amountMl;
  final bool? isBreastMilk;
  final String? formulaType;
  final String? foodDescription;
  final double? pumpedMl;
  final String? notes;

  const FeedEntriesData({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.feedType,
    this.leftDurationSeconds,
    this.rightDurationSeconds,
    this.amountMl,
    this.isBreastMilk,
    this.formulaType,
    this.foodDescription,
    this.pumpedMl,
    this.notes,
  });

  int get totalDurationSeconds =>
      (leftDurationSeconds ?? 0) + (rightDurationSeconds ?? 0);

  String get primaryLabel {
    switch (feedType) {
      case 'breast':
        final mins = totalDurationSeconds ~/ 60;
        return '$mins min nursing';
      case 'bottle':
        return amountMl != null ? '${amountMl!.toStringAsFixed(0)} ml' : 'Bottle';
      case 'solids':
        return foodDescription ?? 'Solids';
      case 'pump':
        return pumpedMl != null ? '${pumpedMl!.toStringAsFixed(0)} ml pumped' : 'Pump';
      default:
        return feedType;
    }
  }
}

// ── Sleep entry data (Drift row type stand-in) ────────────────────────────────

class SleepEntriesData {
  final String id;
  final String babyId;
  final String caregiverId;
  final DateTime timestamp;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;

  const SleepEntriesData({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.startTime,
    this.endTime,
    this.notes,
  });

  bool get isOngoing => endTime == null;

  Duration get duration => isOngoing
      ? DateTime.now().difference(startTime)
      : endTime!.difference(startTime);

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ── Diaper entry data (Drift row type stand-in) ───────────────────────────────

class DiaperEntriesData {
  final String id;
  final String babyId;
  final String caregiverId;
  final DateTime timestamp;
  final String diaperType; // wet / dirty / both / dry
  final String? stoolColor;
  final bool hasRash;
  final String? notes;

  const DiaperEntriesData({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.diaperType,
    this.stoolColor,
    this.hasRash = false,
    this.notes,
  });

  bool get requiresAttention =>
      stoolColor == 'red' || stoolColor == 'black' || stoolColor == 'white';
}

// ── Caregiver data (Drift row type stand-in) ──────────────────────────────────

class CaregiversData {
  final String id;
  final String displayName;
  final String? email;
  final String role; // admin / caregiver / viewer
  final bool isCurrentDevice;

  const CaregiversData({
    required this.id,
    required this.displayName,
    this.email,
    this.role = 'admin',
    this.isCurrentDevice = false,
  });
}

// ── Notification service placeholder ─────────────────────────────────────────

class NotificationService {
  void scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) {}
}

final notificationServiceProvider =
    Provider<NotificationService>((_) => NotificationService());

// ── Active baby ───────────────────────────────────────────────────────────────

final activeBabyIdProvider = StateProvider<String?>((_) => null);

final activeBabyProvider = Provider<BabiesData?>((ref) {
  final id = ref.watch(activeBabyIdProvider);
  final babies = ref.watch(babiesStreamProvider).valueOrNull ?? [];
  if (id == null && babies.isNotEmpty) return babies.first;
  return babies.where((b) => b.id == id).firstOrNull;
});

// ── Babies stream ─────────────────────────────────────────────────────────────

final babiesStreamProvider = StreamProvider<List<BabiesData>>((_) async* {
  yield [];
});

// ── Entry streams (per active baby) ──────────────────────────────────────────

final feedEntriesProvider = StreamProvider<List<FeedEntriesData>>((_) async* {
  yield [];
});

final sleepEntriesProvider = StreamProvider<List<SleepEntriesData>>((_) async* {
  yield [];
});

final diaperEntriesProvider = StreamProvider<List<DiaperEntriesData>>((_) async* {
  yield [];
});

// ── Current caregiver ─────────────────────────────────────────────────────────

final currentCaregiverProvider = FutureProvider<CaregiversData?>((_) async {
  return null;
});
