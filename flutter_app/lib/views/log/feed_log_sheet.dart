import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── Feed Log Sheet ───────────────────────────────────────────────────────────

class FeedLogSheet extends ConsumerStatefulWidget {
  final BabiesData baby;

  const FeedLogSheet({super.key, required this.baby});

  @override
  ConsumerState<FeedLogSheet> createState() => _FeedLogSheetState();
}

class _FeedLogSheetState extends ConsumerState<FeedLogSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle
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

              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EntryColors.feed.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lunch_dining_outlined,
                          color: EntryColors.feed, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Log Feed',
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
              const SizedBox(height: 12),

              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: EntryColors.feed,
                indicatorColor: EntryColors.feed,
                tabs: const [
                  Tab(text: 'Breast'),
                  Tab(text: 'Bottle'),
                  Tab(text: 'Solids'),
                  Tab(text: 'Pump'),
                ],
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _BreastTab(baby: widget.baby),
                    _BottleTab(baby: widget.baby),
                    _SolidsTab(baby: widget.baby),
                    _PumpTab(baby: widget.baby),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Breast Tab ───────────────────────────────────────────────────────────────

class _BreastTab extends ConsumerStatefulWidget {
  final BabiesData baby;
  const _BreastTab({required this.baby});

  @override
  ConsumerState<_BreastTab> createState() => _BreastTabState();
}

class _BreastTabState extends ConsumerState<_BreastTab> {
  int _leftSeconds = 0;
  int _rightSeconds = 0;
  String? _activeSide; // 'left' | 'right' | null
  Timer? _timer;
  bool _saving = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggleSide(String side) {
    HapticManager.medium();
    if (_activeSide == side) {
      // Pause
      _timer?.cancel();
      setState(() => _activeSide = null);
    } else {
      // Switch or start
      _timer?.cancel();
      setState(() => _activeSide = side);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_activeSide == 'left') _leftSeconds++;
          if (_activeSide == 'right') _rightSeconds++;
        });
      });
    }
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    _timer?.cancel();
    setState(() => _saving = true);
    HapticManager.success();

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertFeedEntry(FeedEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      feedType: const Value('breast'),
      leftDurationSeconds: Value(_leftSeconds > 0 ? _leftSeconds : null),
      rightDurationSeconds: Value(_rightSeconds > 0 ? _rightSeconds : null),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(
          SyncOperation(
            modelType: 'feed_entry',
            modelId: id,
            operation: SyncOperationType.insert,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalSec = _leftSeconds + _rightSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Total
          Text(
            'Total: ${_fmt(totalSec)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: EntryColors.feed,
                ),
          ),
          const SizedBox(height: 24),

          // Side buttons
          Row(
            children: [
              Expanded(
                child: _SideTimerButton(
                  label: 'Left',
                  seconds: _leftSeconds,
                  isActive: _activeSide == 'left',
                  onTap: () => _toggleSide('left'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SideTimerButton(
                  label: 'Right',
                  seconds: _rightSeconds,
                  isActive: _activeSide == 'right',
                  onTap: () => _toggleSide('right'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Notes
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // Save
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || totalSec == 0 ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: EntryColors.feed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Feed', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTimerButton extends StatelessWidget {
  final String label;
  final int seconds;
  final bool isActive;
  final VoidCallback onTap;

  const _SideTimerButton({
    required this.label,
    required this.seconds,
    required this.isActive,
    required this.onTap,
  });

  String get _fmt {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 130,
        decoration: BoxDecoration(
          color: isActive
              ? EntryColors.feed.withAlpha(26)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? EntryColors.feed : cs.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.pause_circle_filled : Icons.play_circle_outline,
              size: 36,
              color: isActive ? EntryColors.feed : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? EntryColors.feed : cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmt,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: isActive ? EntryColors.feed : cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottle Tab ───────────────────────────────────────────────────────────────

class _BottleTab extends ConsumerStatefulWidget {
  final BabiesData baby;
  const _BottleTab({required this.baby});

  @override
  ConsumerState<_BottleTab> createState() => _BottleTabState();
}

class _BottleTabState extends ConsumerState<_BottleTab> {
  final _amountCtrl = TextEditingController();
  bool _isBreastMilk = true;
  String _formulaType = 'standard';
  bool _saving = false;
  final _notesCtrl = TextEditingController();

  static const _formulaOptions = [
    ('standard', 'Standard'),
    ('sensitive', 'Sensitive'),
    ('soy', 'Soy'),
    ('hypoallergenic', 'Hypoallergenic'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    HapticManager.success();

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertFeedEntry(FeedEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      feedType: const Value('bottle'),
      amountMl: Value(amount),
      isBreastMilk: Value(_isBreastMilk),
      formulaType: Value(_isBreastMilk ? null : _formulaType),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'feed_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Amount',
              suffixText: 'ml',
              prefixIcon: Icon(Icons.local_drink_outlined),
            ),
          ),
          const SizedBox(height: 20),

          // Breast milk toggle
          SwitchListTile.adaptive(
            value: _isBreastMilk,
            onChanged: (v) => setState(() => _isBreastMilk = v),
            title: const Text('Breast Milk'),
            contentPadding: EdgeInsets.zero,
            activeColor: EntryColors.feed,
          ),

          // Formula type picker
          if (!_isBreastMilk) ...[
            const SizedBox(height: 8),
            Text('Formula Type',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _formulaOptions.map((opt) {
                final selected = _formulaType == opt.$1;
                return ChoiceChip(
                  label: Text(opt.$2),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _formulaType = opt.$1),
                  selectedColor: EntryColors.feed.withAlpha(51),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: EntryColors.feed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Feed', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Solids Tab ───────────────────────────────────────────────────────────────

class _SolidsTab extends ConsumerStatefulWidget {
  final BabiesData baby;
  const _SolidsTab({required this.baby});

  @override
  ConsumerState<_SolidsTab> createState() => _SolidsTabState();
}

class _SolidsTabState extends ConsumerState<_SolidsTab> {
  final _foodCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _foodCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_foodCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);
    HapticManager.success();

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertFeedEntry(FeedEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      feedType: const Value('solids'),
      foodDescription: Value(_foodCtrl.text.trim()),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'feed_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _foodCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What did baby eat? (e.g. "Pureed sweet potato, rice cereal")',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.restaurant_outlined),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: EntryColors.feed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Feed', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pump Tab ─────────────────────────────────────────────────────────────────

class _PumpTab extends ConsumerStatefulWidget {
  final BabiesData baby;
  const _PumpTab({required this.baby});

  @override
  ConsumerState<_PumpTab> createState() => _PumpTabState();
}

class _PumpTabState extends ConsumerState<_PumpTab> {
  final _leftCtrl = TextEditingController();
  final _rightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final left = double.tryParse(_leftCtrl.text) ?? 0;
    final right = double.tryParse(_rightCtrl.text) ?? 0;
    final total = left + right;
    if (total <= 0) return;

    setState(() => _saving = true);
    HapticManager.success();

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertFeedEntry(FeedEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      feedType: const Value('pump'),
      pumpedMl: Value(total),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'feed_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _leftCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Left',
                    suffixText: 'ml',
                    prefixIcon: Icon(Icons.arrow_back),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Right',
                    suffixText: 'ml',
                    prefixIcon: Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              hintText: 'Notes (optional)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: EntryColors.feed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Pump', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── databaseProvider shim ────────────────────────────────────────────────────
// Declare the real AppDatabase provider here — your providers.dart provides
// only placeholder types, so we expose AppDatabase through a local provider.

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
