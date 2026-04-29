import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';
import '../../widgets/toast.dart';

class QuickNoteSheet extends ConsumerStatefulWidget {
  final BabiesData baby;
  const QuickNoteSheet({super.key, required this.baby});

  @override
  ConsumerState<QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends ConsumerState<QuickNoteSheet> {
  final _ctrl = TextEditingController();
  HandoffNotesData? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _loadExisting() async {
    final db = ref.read(databaseProvider);
    final note = await (db.select(db.handoffNotes)
          ..where((n) => n.babyId.equals(widget.baby.id))
          ..orderBy([(n) => OrderingTerm.desc(n.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    if (mounted) setState(() { _existing = note; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Handoff Note', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                    ],
                  ),
                ],
              ),
            ),
            if (_loaded && _existing != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Previous note — ${DateFormat.MMMd().add_jm().format(_existing!.timestamp)}',
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_existing!.body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const Divider(indent: 24, endIndent: 24),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Write a note for the next caregiver...',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _ctrl.text.isEmpty ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_ctrl.text.trim().isEmpty) return;
    HapticManager.success();
    final db = ref.read(databaseProvider);
    final caregiver = await db.getCurrentCaregiver();
    final sync = ref.read(syncManagerProvider.notifier);
    final id = const Uuid().v4();

    await db.into(db.handoffNotes).insertOnConflictUpdate(HandoffNotesCompanion.insert(
      id: id,
      babyId: widget.baby.id,
      caregiverId: caregiver?.id ?? const Uuid().v4(),
      body: _ctrl.text.trim(),
      timestamp: DateTime.now(),
    ));

    sync.enqueue(SyncOperation(
      modelType: 'HandoffNote', modelId: id,
      operation: SyncOperationType.insert,
      payload: {'baby_id': widget.baby.id, 'body': _ctrl.text.trim()},
    ));

    if (mounted) {
      showToast('Note saved', style: ToastStyle.success);
      Navigator.of(context).pop();
    }
  }
}
