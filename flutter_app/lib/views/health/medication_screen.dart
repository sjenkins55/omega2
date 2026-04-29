import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/health.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── Medication Screen ─────────────────────────────────────────────────────────

class MedicationScreen extends ConsumerStatefulWidget {
  final BabiesData baby;
  const MedicationScreen({super.key, required this.baby});

  @override
  ConsumerState<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends ConsumerState<MedicationScreen> {
  Future<void> _stopMedication(MedicationsData med) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.upsertMedication(MedicationsCompanion(
      id: Value(med.id),
      babyId: Value(med.babyId),
      createdById: Value(med.createdById),
      name: Value(med.name),
      dose: Value(med.dose),
      doseUnit: Value(med.doseUnit),
      route: Value(med.route),
      isScheduled: Value(med.isScheduled),
      frequencyHours: Value(med.frequencyHours),
      startDate: Value(med.startDate),
      endDate: Value(now),
      isActive: const Value(false),
      prescribedBy: Value(med.prescribedBy),
      notes: Value(med.notes),
      syncStatus: const Value('pending'),
      createdAt: Value(med.createdAt),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'medication',
          modelId: med.id,
          operation: SyncOperationType.update,
          payload: {
            'id': med.id,
            'isActive': false,
            'endDate': now.toIso8601String(),
          },
        ));
  }

  Future<void> _showAddEditDialog([MedicationsData? existing]) async {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final doseController =
        TextEditingController(text: existing?.dose.toString() ?? '');
    final prescriberController =
        TextEditingController(text: existing?.prescribedBy ?? '');
    final notesController =
        TextEditingController(text: existing?.notes ?? '');
    final freqController = TextEditingController(
        text: existing?.frequencyHours?.toString() ?? '');

    DoseUnit selectedUnit =
        DoseUnit.values.firstWhere((u) => u.name == (existing?.doseUnit ?? 'mg'),
            orElse: () => DoseUnit.mg);
    MedRoute selectedRoute =
        MedRoute.values.firstWhere((r) => r.name == (existing?.route ?? 'oral'),
            orElse: () => MedRoute.oral);
    bool isScheduled = existing?.isScheduled ?? false;
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Medication' : 'Edit Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Dose + unit row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Dose',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<DoseUnit>(
                      value: selectedUnit,
                      items: DoseUnit.values
                          .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setS(() => selectedUnit = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Route picker
                const Text('Route', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: MedRoute.values.map((r) {
                    return ChoiceChip(
                      label: Text(_routeLabel(r)),
                      selected: selectedRoute == r,
                      onSelected: (_) => setS(() => selectedRoute = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Scheduled toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scheduled'),
                  subtitle: const Text('Give on a regular schedule'),
                  value: isScheduled,
                  onChanged: (v) => setS(() => isScheduled = v),
                ),

                if (isScheduled) ...[
                  TextField(
                    controller: freqController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Frequency (every X hours)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Start date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(DateFormat.yMMMd().format(startDate)),
                  subtitle: const Text('Start Date'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setS(() => startDate = d);
                  },
                ),

                // End date (optional)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.stop_circle_outlined,
                    color: endDate != null ? Colors.orange : Colors.grey,
                  ),
                  title: Text(endDate != null
                      ? DateFormat.yMMMd().format(endDate!)
                      : 'No end date'),
                  subtitle: const Text('End Date (optional)'),
                  trailing: endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setS(() => endDate = null),
                        )
                      : null,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setS(() => endDate = d);
                  },
                ),

                // Prescriber
                TextField(
                  controller: prescriberController,
                  decoration: const InputDecoration(
                    labelText: 'Prescribed By (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesController,
                  maxLines: 2,
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
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final dose = double.tryParse(doseController.text.trim()) ?? 0;

    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final id = existing?.id ?? const Uuid().v4();
    final now = DateTime.now();

    await db.upsertMedication(MedicationsCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      createdById: Value(caregiverId),
      name: Value(name),
      dose: Value(dose),
      doseUnit: Value(selectedUnit.name),
      route: Value(selectedRoute.name),
      isScheduled: Value(isScheduled),
      frequencyHours: Value(
          isScheduled ? double.tryParse(freqController.text.trim()) : null),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isActive: const Value(true),
      prescribedBy: prescriberController.text.trim().isEmpty
          ? const Value.absent()
          : Value(prescriberController.text.trim()),
      notes: notesController.text.trim().isEmpty
          ? const Value.absent()
          : Value(notesController.text.trim()),
      syncStatus: const Value('pending'),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'medication',
          modelId: id,
          operation: existing == null
              ? SyncOperationType.insert
              : SyncOperationType.update,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'name': name,
            'dose': dose,
            'doseUnit': selectedUnit.name,
            'route': selectedRoute.name,
            'isScheduled': isScheduled,
            'startDate': startDate.toIso8601String(),
          },
        ));
  }

  String _routeLabel(MedRoute r) {
    switch (r) {
      case MedRoute.oral:
        return 'Oral';
      case MedRoute.topical:
        return 'Topical';
      case MedRoute.inhaled:
        return 'Inhaled';
      case MedRoute.nasal:
        return 'Nasal';
      case MedRoute.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicationsStream = ref.watch(databaseProvider).watchMedications(widget.baby.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: StreamBuilder<List<MedicationsData>>(
        stream: medicationsStream,
        builder: (context, snap) {
          final all = snap.data ?? [];
          final active = all.where((m) => m.isActive).toList();
          final past = all.where((m) => !m.isActive).toList();

          if (all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No medications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text('Tap + to add a medication',
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
                ...active.map((med) => _MedicationTile(
                      med: med,
                      onEdit: () => _showAddEditDialog(med),
                      onStop: () => _stopMedication(med),
                    )),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader(title: 'Past (${past.length})'),
                ...past.map((med) => _MedicationTile(
                      med: med,
                      onEdit: null,
                      onStop: null,
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
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

// ─── Medication Tile ───────────────────────────────────────────────────────────

class _MedicationTile extends StatelessWidget {
  final MedicationsData med;
  final VoidCallback? onEdit;
  final VoidCallback? onStop;

  const _MedicationTile({
    required this.med,
    required this.onEdit,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF9C27B0).withOpacity(0.12),
          child: const Icon(Icons.medication, color: Color(0xFF9C27B0)),
        ),
        title: Text(med.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${med.dose} ${med.doseUnit} · ${med.route}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Since ${DateFormat.yMMMd().format(med.startDate)}'
              '${med.endDate != null ? ' – ${DateFormat.yMMMd().format(med.endDate!)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: med.isActive
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Stopped',
                    style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
      ),
    );

    if (onEdit == null && onStop == null) return tile;

    return Dismissible(
      key: ValueKey(med.id),
      background: _SwipeBackground(
        color: Colors.blue,
        icon: Icons.edit,
        label: 'Edit',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: Colors.orange,
        icon: Icons.stop_circle_outlined,
        label: 'Stop',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd && onEdit != null) {
          onEdit!();
        } else if (dir == DismissDirection.endToStart && onStop != null) {
          onStop!();
        }
        return false; // never remove the tile
      },
      child: tile,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
