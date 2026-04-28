import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_types.dart';
import 'supabase_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SyncState {
  final bool isOnline;
  final int pendingCount;

  const SyncState({required this.isOnline, required this.pendingCount});

  SyncState copyWith({bool? isOnline, int? pendingCount}) => SyncState(
        isOnline: isOnline ?? this.isOnline,
        pendingCount: pendingCount ?? this.pendingCount,
      );
}

// ─── SyncManager ─────────────────────────────────────────────────────────────

class SyncManager extends StateNotifier<SyncState> {
  final SupabaseService _supabase;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = false;
  bool _isSyncing = false;

  static const _queueKey = 'sync_queue';

  SyncManager(this._supabase)
      : super(const SyncState(isOnline: false, pendingCount: 0)) {
    _init();
  }

  Future<void> _init() async {
    // Seed pending count from persisted queue before connectivity lands.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    state = state.copyWith(pendingCount: raw.length);

    // Start connectivity monitoring.
    _startMonitoring();
  }

  void _startMonitoring() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      state = state.copyWith(isOnline: _isOnline);
      if (_isOnline && wasOffline) await _drain();
    });
  }

  /// Add a [SyncOperation] to the persistent queue.
  /// If already online, attempts to drain the queue immediately.
  Future<void> enqueue(SyncOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    raw.add(jsonEncode(op.toJson()));
    await prefs.setStringList(_queueKey, raw);
    state = state.copyWith(pendingCount: raw.length);
    if (_isOnline) unawaited(_drain());
  }

  /// Force a sync attempt regardless of whether connectivity changed.
  Future<void> forceSync() async {
    if (_isOnline) await _drain();
  }

  Future<void> _drain() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      if (raw.isEmpty) return;

      final ops = raw
          .map((s) =>
              SyncOperation.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();

      final remaining = <SyncOperation>[];

      for (final op in ops) {
        try {
          await _push(op);
        } catch (_) {
          op.retryCount++;
          op.lastAttemptAt = DateTime.now();
          // Discard after reaching the max retry cap.
          if (op.retryCount < 5) remaining.add(op);
        }
      }

      await prefs.setStringList(
        _queueKey,
        remaining.map((o) => jsonEncode(o.toJson())).toList(),
      );
      state = state.copyWith(pendingCount: remaining.length);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _push(SyncOperation op) async {
    final table = _tableName(op.modelType);
    switch (op.operation) {
      case SyncOperationType.insert:
      case SyncOperationType.update:
        await _supabase.upsert(table, op.payload);
        break;
      case SyncOperationType.delete:
        final remoteId = op.payload['remoteId'] as String?;
        if (remoteId != null) await _supabase.delete(table, remoteId);
        break;
    }
  }

  String _tableName(String modelType) {
    const map = <String, String>{
      'Baby': 'babies',
      'FeedEntry': 'feed_entries',
      'SleepEntry': 'sleep_entries',
      'DiaperEntry': 'diaper_entries',
      'TemperatureEntry': 'temperature_entries',
      'Measurement': 'measurements',
      'MilestoneEntry': 'milestone_entries',
      'VaccineEntry': 'vaccine_entries',
      'Appointment': 'appointments',
      'Medication': 'medications',
      'MedicationDose': 'medication_doses',
      'Illness': 'illnesses',
      'Caregiver': 'caregivers',
      'BabyAccess': 'baby_access',
      'HandoffNote': 'handoff_notes',
      'CaregiverInvite': 'caregiver_invites',
    };
    return map[modelType] ?? '${modelType.toLowerCase()}s';
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// ignore: avoid_void_async
void unawaited(Future<void> future) {
  // Intentionally fire-and-forget; errors are handled inside _drain().
}
