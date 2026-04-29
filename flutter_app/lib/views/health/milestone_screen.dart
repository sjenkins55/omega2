import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── Milestone Data ────────────────────────────────────────────────────────────

class _MilestoneInfo {
  final String key;
  final String title;
  final String emoji;
  final int expectedMonths; // rough guide only

  const _MilestoneInfo({
    required this.key,
    required this.title,
    required this.emoji,
    required this.expectedMonths,
  });
}

const _coreMilestones = [
  _MilestoneInfo(key: 'smiles',           title: 'Smiles',               emoji: '😄', expectedMonths: 2),
  _MilestoneInfo(key: 'holds_head_up',    title: 'Holds head up',        emoji: '🐣', expectedMonths: 3),
  _MilestoneInfo(key: 'laughs',           title: 'Laughs',               emoji: '😂', expectedMonths: 4),
  _MilestoneInfo(key: 'rolls_over',       title: 'Rolls over',           emoji: '🔄', expectedMonths: 5),
  _MilestoneInfo(key: 'sits_without',     title: 'Sits without support', emoji: '🪑', expectedMonths: 6),
  _MilestoneInfo(key: 'stands_with_help', title: 'Stands with help',     emoji: '🧍', expectedMonths: 9),
  _MilestoneInfo(key: 'first_steps',      title: 'First steps',          emoji: '👣', expectedMonths: 12),
  _MilestoneInfo(key: 'first_words',      title: 'First words',          emoji: '💬', expectedMonths: 12),
];

// ─── Milestone Screen ──────────────────────────────────────────────────────────

class MilestoneScreen extends ConsumerStatefulWidget {
  final BabiesData baby;
  const MilestoneScreen({super.key, required this.baby});

  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen> {
  bool _galleryMode = true;

  Future<void> _markAchieved(_MilestoneInfo info) async {
    DateTime achievedDate = DateTime.now();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text('${info.emoji} ${info.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat.yMMMd().format(achievedDate)),
                subtitle: const Text('Date Achieved'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: achievedDate,
                    firstDate: widget.baby.dateOfBirth,
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setS(() => achievedDate = d);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      }),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertMilestoneEntry(MilestoneEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiverId),
      timestamp: Value(achievedDate),
      milestoneKey: Value(info.key),
      achievedAt: Value(achievedDate),
      notes: notesController.text.trim().isEmpty
          ? const Value.absent()
          : Value(notesController.text.trim()),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'milestoneEntry',
          modelId: id,
          operation: SyncOperationType.insert,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'caregiverId': caregiverId,
            'milestoneKey': info.key,
            'achievedAt': achievedDate.toIso8601String(),
            'notes': notesController.text.trim(),
          },
        ));
  }

  Future<void> _showAddCustomMilestoneDialog() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime achievedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Custom Milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat.yMMMd().format(achievedDate)),
                  subtitle: const Text('Date Achieved'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: achievedDate,
                      firstDate: widget.baby.dateOfBirth,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => achievedDate = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      }),
    );

    if (confirmed != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertMilestoneEntry(MilestoneEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiverId),
      timestamp: Value(achievedDate),
      customTitle: Value(title),
      achievedAt: Value(achievedDate),
      notes: notesController.text.trim().isEmpty
          ? const Value.absent()
          : Value(notesController.text.trim()),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'milestoneEntry',
          modelId: id,
          operation: SyncOperationType.insert,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'caregiverId': caregiverId,
            'customTitle': title,
            'achievedAt': achievedDate.toIso8601String(),
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final milestoneStream = db.watchMilestones(widget.baby.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milestones'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Gallery'), icon: Icon(Icons.grid_view)),
                ButtonSegment(value: false, label: Text('Timeline'), icon: Icon(Icons.view_timeline)),
              ],
              selected: {_galleryMode},
              onSelectionChanged: (s) => setState(() => _galleryMode = s.first),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<MilestoneEntriesData>>(
        stream: milestoneStream,
        builder: (context, snap) {
          final entries = snap.data ?? [];
          final achievedByKey = {
            for (final e in entries)
              if (e.milestoneKey != null) e.milestoneKey!: e,
          };
          final customEntries =
              entries.where((e) => e.milestoneKey == null).toList();

          if (_galleryMode) {
            return _GalleryView(
              baby: widget.baby,
              coreMilestones: _coreMilestones,
              achievedByKey: achievedByKey,
              customEntries: customEntries,
              onMarkAchieved: _markAchieved,
            );
          } else {
            return _TimelineView(
              entries: entries,
              achievedByKey: achievedByKey,
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomMilestoneDialog,
        icon: const Icon(Icons.add),
        label: const Text('Custom'),
      ),
    );
  }
}

// ─── Gallery View ──────────────────────────────────────────────────────────────

class _GalleryView extends StatelessWidget {
  final BabiesData baby;
  final List<_MilestoneInfo> coreMilestones;
  final Map<String, MilestoneEntriesData> achievedByKey;
  final List<MilestoneEntriesData> customEntries;
  final void Function(_MilestoneInfo) onMarkAchieved;

  const _GalleryView({
    required this.baby,
    required this.coreMilestones,
    required this.achievedByKey,
    required this.customEntries,
    required this.onMarkAchieved,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final allItems = [
      ...coreMilestones.map((m) => _GalleryItem.core(m, achievedByKey[m.key])),
      ...customEntries.map((e) => _GalleryItem.custom(e)),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, i) {
        final item = allItems[i];
        final achieved = item.achievedEntry != null;

        return Card(
          clipBehavior: Clip.antiAlias,
          color: achieved
              ? colorScheme.primaryContainer.withOpacity(0.5)
              : colorScheme.surfaceVariant.withOpacity(0.3),
          child: InkWell(
            onTap: achieved || item.coreInfo == null
                ? null
                : () => onMarkAchieved(item.coreInfo!),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji / icon
                  Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: achieved
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (achieved) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMd().format(item.achievedEntry!.achievedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (item.coreInfo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tap to achieve',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GalleryItem {
  final _MilestoneInfo? coreInfo;
  final MilestoneEntriesData? achievedEntry;
  final String emoji;
  final String title;

  _GalleryItem.core(_MilestoneInfo info, MilestoneEntriesData? entry)
      : coreInfo = info,
        achievedEntry = entry,
        emoji = info.emoji,
        title = info.title;

  _GalleryItem.custom(MilestoneEntriesData entry)
      : coreInfo = null,
        achievedEntry = entry,
        emoji = '⭐',
        title = entry.customTitle ?? 'Milestone';
}

// ─── Timeline View ─────────────────────────────────────────────────────────────

class _TimelineView extends StatelessWidget {
  final List<MilestoneEntriesData> entries;
  final Map<String, MilestoneEntriesData> achievedByKey;

  const _TimelineView({
    required this.entries,
    required this.achievedByKey,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    if (sorted.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👣', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('No milestones yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Text('Tap a milestone card to mark it achieved',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, i) {
        final entry = sorted[i];
        final isCore = entry.milestoneKey != null;
        final coreInfo = isCore
            ? _coreMilestones
                .where((m) => m.key == entry.milestoneKey)
                .firstOrNull
            : null;
        final emoji = coreInfo?.emoji ?? '⭐';
        final title = coreInfo?.title ?? entry.customTitle ?? 'Milestone';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                if (i < sorted.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.withOpacity(0.2),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMMd().format(entry.achievedAt),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(entry.notes!,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── DB Extension (watchMilestones) ───────────────────────────────────────────

extension _MilestoneDao on AppDatabase {
  Stream<List<MilestoneEntriesData>> watchMilestones(String babyId) {
    return (select(milestoneEntries)
          ..where((m) => m.babyId.equals(babyId))
          ..orderBy([(m) => OrderingTerm.desc(m.achievedAt)]))
        .watch();
  }
}
