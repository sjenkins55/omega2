import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/health.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── Illness Screen ────────────────────────────────────────────────────────────

class IllnessScreen extends ConsumerStatefulWidget {
  final BabiesData baby;
  const IllnessScreen({super.key, required this.baby});

  @override
  ConsumerState<IllnessScreen> createState() => _IllnessScreenState();
}

class _IllnessScreenState extends ConsumerState<IllnessScreen> {
  List<Symptom> _symptomsFromJson(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((s) => Symptom.values.firstWhere(
                (e) => e.name == s,
                orElse: () => Symptom.other,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _resolveIllness(IllnessesData illness) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Resolved?'),
        content: const Text('This will set the end date to today.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resolve')),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.upsertIllness(IllnessesCompanion(
      id: Value(illness.id),
      babyId: Value(illness.babyId),
      caregiverId: Value(illness.caregiverId),
      onsetDate: Value(illness.onsetDate),
      endDate: Value(now),
      symptomsJson: Value(illness.symptomsJson),
      notes: Value(illness.notes),
      syncStatus: const Value('pending'),
      createdAt: Value(illness.createdAt),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'illness',
          modelId: illness.id,
          operation: SyncOperationType.update,
          payload: {
            'id': illness.id,
            'endDate': now.toIso8601String(),
          },
        ));
  }

  Future<void> _showAddIllnessDialog() async {
    DateTime onsetDate = DateTime.now();
    DateTime? endDate;
    bool isResolved = false;
    final selectedSymptoms = <Symptom>{};
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Log Illness'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Onset date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sick_outlined),
                  title: Text(DateFormat.yMMMd().format(onsetDate)),
                  subtitle: const Text('Onset Date'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: onsetDate,
                      firstDate: widget.baby.dateOfBirth,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => onsetDate = d);
                  },
                ),

                // Resolved toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resolved'),
                  value: isResolved,
                  onChanged: (v) => setS(() {
                    isResolved = v;
                    if (!v) endDate = null;
                    if (v && endDate == null) endDate = DateTime.now();
                  }),
                ),

                if (isResolved)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.healing_outlined),
                    title: Text(endDate != null
                        ? DateFormat.yMMMd().format(endDate!)
                        : 'Select date'),
                    subtitle: const Text('Recovery Date'),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: onsetDate,
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setS(() => endDate = d);
                    },
                  ),

                const SizedBox(height: 12),
                const Text('Symptoms',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                // Symptom chips grid
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: Symptom.values.map((symptom) {
                    final selected = selectedSymptoms.contains(symptom);
                    return FilterChip(
                      label: Text(symptom.label),
                      selected: selected,
                      selectedColor: Colors.orange.withOpacity(0.2),
                      checkmarkColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: selected ? Colors.orange : Colors.grey,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      onSelected: (v) {
                        setS(() {
                          if (v) {
                            selectedSymptoms.add(symptom);
                          } else {
                            selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                    );
                  }).toList(),
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

    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final symptomsJson =
        jsonEncode(selectedSymptoms.map((s) => s.name).toList());

    await db.upsertIllness(IllnessesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiverId),
      onsetDate: Value(onsetDate),
      endDate: Value(isResolved ? endDate : null),
      symptomsJson: Value(symptomsJson),
      notes: notesController.text.trim().isEmpty
          ? const Value.absent()
          : Value(notesController.text.trim()),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'illness',
          modelId: id,
          operation: SyncOperationType.insert,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'caregiverId': caregiverId,
            'onsetDate': onsetDate.toIso8601String(),
            'endDate': isResolved ? endDate?.toIso8601String() : null,
            'symptomsJson': symptomsJson,
            'notes': notesController.text.trim(),
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final illnessesStream = ref.watch(databaseProvider).watchIllnesses(widget.baby.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Illness Log')),
      body: StreamBuilder<List<IllnessesData>>(
        stream: illnessesStream,
        builder: (context, snap) {
          final all = snap.data ?? [];
          final active = all.where((i) => i.endDate == null).toList();
          final past = all.where((i) => i.endDate != null).toList();

          if (all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🤒', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text('No illness records',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text('Tap + to log an illness',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(title: 'Active (${active.length})'),
                ...active.map((illness) => _IllnessTile(
                      illness: illness,
                      symptoms: _symptomsFromJson(illness.symptomsJson),
                      onResolve: () => _resolveIllness(illness),
                    )),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader(title: 'Past (${past.length})'),
                ...past.map((illness) => _IllnessTile(
                      illness: illness,
                      symptoms: _symptomsFromJson(illness.symptomsJson),
                      onResolve: null,
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIllnessDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          )),
    );
  }
}

// ─── Illness Tile ──────────────────────────────────────────────────────────────

class _IllnessTile extends StatelessWidget {
  final IllnessesData illness;
  final List<Symptom> symptoms;
  final VoidCallback? onResolve;

  const _IllnessTile({
    required this.illness,
    required this.symptoms,
    required this.onResolve,
  });

  int get _daysActive {
    final end = illness.endDate ?? DateTime.now();
    return end.difference(illness.onsetDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = illness.endDate == null;

    final tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.red.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Recovered',
                    style: TextStyle(
                      color: isActive ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_daysActive ${_daysActive == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Onset: ${DateFormat.yMMMd().format(illness.onsetDate)}'
              '${illness.endDate != null ? '  ·  Resolved: ${DateFormat.yMMMd().format(illness.endDate!)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (symptoms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: symptoms
                    .map((s) => Chip(
                          label: Text(s.label,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor:
                              Colors.orange.withOpacity(0.12),
                          side: BorderSide.none,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        ))
                    .toList(),
              ),
            ],
            if (illness.notes != null && illness.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(illness.notes!,
                  style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );

    if (onResolve == null) return tile;

    return Dismissible(
      key: ValueKey(illness.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.healing, color: Colors.green),
            Text('Resolve',
                style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onResolve!();
        return false;
      },
      child: tile,
    );
  }
}
