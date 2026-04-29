import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';
import '../log/feed_log_sheet.dart' show databaseProvider;

class SleepLogSheet extends ConsumerStatefulWidget {
  final BabiesData baby;

  const SleepLogSheet({super.key, required this.baby});

  @override
  ConsumerState<SleepLogSheet> createState() => _SleepLogSheetState();
}

class _SleepLogSheetState extends ConsumerState<SleepLogSheet> {
  SleepEntriesData? _activeSleep;
  bool _loading = true;
  bool _saving = false;

  // For manual entry
  bool _isManualMode = false;
  DateTime? _manualStart;
  DateTime? _manualEnd;

  // Live elapsed timer for active sleep
  Timer? _liveTimer;
  Duration _elapsed = Duration.zero;

  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActiveSleep();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveSleep() async {
    final db = ref.read(databaseProvider);
    final active = await db.getActiveSleep(widget.baby.id);
    if (!mounted) return;
    setState(() {
      _activeSleep = active != null ? _toSleepEntriesData(active) : null;
      _loading = false;
    });
    if (_activeSleep != null) {
      _startLiveTimer();
    }
  }

  SleepEntriesData _toSleepEntriesData(SleepEntriesData raw) => raw;

  void _startLiveTimer() {
    _elapsed = DateTime.now().difference(_activeSleep!.startTime);
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_activeSleep!.startTime);
      });
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startSleep() async {
    HapticManager.success();
    setState(() => _saving = true);

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertSleepEntry(SleepEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      startTime: Value(now),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'sleep_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stopSleep() async {
    if (_activeSleep == null) return;
    HapticManager.success();
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.upsertSleepEntry(SleepEntriesCompanion(
      id: Value(_activeSleep!.id),
      babyId: Value(_activeSleep!.babyId),
      caregiverId: Value(_activeSleep!.caregiverId),
      timestamp: Value(_activeSleep!.timestamp),
      startTime: Value(_activeSleep!.startTime),
      endTime: Value(now),
      notes: Value(_notesCtrl.text.trim().isEmpty
          ? _activeSleep!.notes
          : _notesCtrl.text.trim()),
      createdAt: Value(_activeSleep!.timestamp),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'sleep_entry',
          modelId: _activeSleep!.id,
          operation: SyncOperationType.update,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveManual() async {
    if (_manualStart == null || _manualEnd == null) return;
    if (_manualEnd!.isBefore(_manualStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    HapticManager.success();
    setState(() => _saving = true);

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertSleepEntry(SleepEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(_manualStart!),
      startTime: Value(_manualStart!),
      endTime: Value(_manualEnd!),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'sleep_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_manualStart ?? DateTime.now())
        : (_manualEnd ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _manualStart = result;
      } else {
        _manualEnd = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM d, h:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EntryColors.sleep.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bedtime_outlined,
                          color: EntryColors.sleep, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Log Sleep',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: _activeSleep != null
                        ? _ActiveSleepContent(
                            elapsed: _elapsed,
                            startTime: _activeSleep!.startTime,
                            notesCtrl: _notesCtrl,
                            saving: _saving,
                            onStop: _stopSleep,
                          )
                        : _isManualMode
                            ? _ManualEntryContent(
                                manualStart: _manualStart,
                                manualEnd: _manualEnd,
                                onPickStart: () => _pickDateTime(isStart: true),
                                onPickEnd: () => _pickDateTime(isStart: false),
                                notesCtrl: _notesCtrl,
                                saving: _saving,
                                onSave: _saveManual,
                                onCancel: () =>
                                    setState(() => _isManualMode = false),
                                fmt: fmt,
                              )
                            : _IdleSleepContent(
                                saving: _saving,
                                onStart: _startSleep,
                                onManual: () =>
                                    setState(() => _isManualMode = true),
                                notesCtrl: _notesCtrl,
                              ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Active sleep display ─────────────────────────────────────────────────────

class _ActiveSleepContent extends StatelessWidget {
  final Duration elapsed;
  final DateTime startTime;
  final TextEditingController notesCtrl;
  final bool saving;
  final VoidCallback onStop;

  const _ActiveSleepContent({
    required this.elapsed,
    required this.startTime,
    required this.notesCtrl,
    required this.saving,
    required this.onStop,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    return Column(
      children: [
        const Icon(Icons.bedtime, size: 64, color: EntryColors.sleep),
        const SizedBox(height: 16),
        Text('Baby is sleeping',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 4),
        Text('Started at ${fmt.format(startTime)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 24),
        Text(
          _fmt(elapsed),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: EntryColors.sleep,
              ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            hintText: 'Notes (optional)',
            prefixIcon: Icon(Icons.note_outlined),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Stop Sleep', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: EntryColors.sleep,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Idle (no active sleep) ───────────────────────────────────────────────────

class _IdleSleepContent extends StatelessWidget {
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback onManual;
  final TextEditingController notesCtrl;

  const _IdleSleepContent({
    required this.saving,
    required this.onStart,
    required this.onManual,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.bedtime_outlined, size: 72, color: EntryColors.sleep),
        const SizedBox(height: 20),
        Text('Track a sleep session',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 8),
        Text(
          "Tap Start Sleep to begin a live timer, or log a past sleep manually.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            hintText: 'Notes (optional)',
            prefixIcon: Icon(Icons.note_outlined),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onStart,
            icon: const Icon(Icons.play_circle_outline),
            label: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Start Sleep', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: EntryColors.sleep,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onManual,
          child: const Text('Log past sleep manually'),
        ),
      ],
    );
  }
}

// ─── Manual entry UI ──────────────────────────────────────────────────────────

class _ManualEntryContent extends StatelessWidget {
  final DateTime? manualStart;
  final DateTime? manualEnd;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final TextEditingController notesCtrl;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final DateFormat fmt;

  const _ManualEntryContent({
    required this.manualStart,
    required this.manualEnd,
    required this.onPickStart,
    required this.onPickEnd,
    required this.notesCtrl,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Duration? duration;
    if (manualStart != null && manualEnd != null) {
      duration = manualEnd!.difference(manualStart!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manual Entry',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 20),

        // Start time
        InkWell(
          onTap: onPickStart,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, color: EntryColors.sleep),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Time',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            )),
                    Text(
                      manualStart != null ? fmt.format(manualStart!) : 'Tap to set',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // End time
        InkWell(
          onTap: onPickEnd,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.stop_circle_outlined, color: EntryColors.sleep),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Time',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            )),
                    Text(
                      manualEnd != null ? fmt.format(manualEnd!) : 'Tap to set',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (duration != null && duration.inMinutes > 0) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Duration: ${duration.inHours}h ${duration.inMinutes % 60}m',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: EntryColors.sleep,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            hintText: 'Notes (optional)',
            prefixIcon: Icon(Icons.note_outlined),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: saving ||
                        manualStart == null ||
                        manualEnd == null
                    ? null
                    : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: EntryColors.sleep,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
