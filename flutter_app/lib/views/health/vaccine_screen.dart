import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── Schedule Data ─────────────────────────────────────────────────────────────

class _VaccineInfo {
  final String key;
  final String name;
  final String ageBand;

  const _VaccineInfo({
    required this.key,
    required this.name,
    required this.ageBand,
  });
}

const _vaccineSchedule = [
  _VaccineInfo(key: 'hep_b_birth', name: 'Hepatitis B', ageBand: 'Birth'),
  _VaccineInfo(key: 'dtap_2m', name: 'DTaP', ageBand: '2 months'),
  _VaccineInfo(key: 'hib_2m', name: 'Hib', ageBand: '2 months'),
  _VaccineInfo(key: 'pcv13_2m', name: 'PCV13', ageBand: '2 months'),
  _VaccineInfo(key: 'ipv_2m', name: 'IPV', ageBand: '2 months'),
  _VaccineInfo(key: 'dtap_4m', name: 'DTaP', ageBand: '4 months'),
  _VaccineInfo(key: 'hib_4m', name: 'Hib', ageBand: '4 months'),
  _VaccineInfo(key: 'pcv13_4m', name: 'PCV13', ageBand: '4 months'),
  _VaccineInfo(key: 'ipv_4m', name: 'IPV', ageBand: '4 months'),
  _VaccineInfo(key: 'dtap_6m', name: 'DTaP', ageBand: '6 months'),
  _VaccineInfo(key: 'hib_6m', name: 'Hib', ageBand: '6 months'),
  _VaccineInfo(key: 'pcv13_6m', name: 'PCV13', ageBand: '6 months'),
  _VaccineInfo(key: 'hep_b_6m', name: 'Hepatitis B', ageBand: '6 months'),
  _VaccineInfo(key: 'mmr_12m', name: 'MMR', ageBand: '12 months'),
  _VaccineInfo(key: 'varicella_12m', name: 'Varicella', ageBand: '12 months'),
  _VaccineInfo(key: 'dtap_15m', name: 'DTaP', ageBand: '15–18 months'),
  _VaccineInfo(key: 'hib_15m', name: 'Hib', ageBand: '15–18 months'),
  _VaccineInfo(key: 'pcv13_15m', name: 'PCV13', ageBand: '15–18 months'),
];

const _ageBands = [
  'Birth',
  '2 months',
  '4 months',
  '6 months',
  '12 months',
  '15–18 months',
];

// ─── Progress Ring Painter ─────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final Color trackColor;

  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    const startAngle = -math.pi / 2;
    const strokeWidth = 4.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Vaccine Screen ────────────────────────────────────────────────────────────

class VaccineScreen extends ConsumerStatefulWidget {
  final BabiesData baby;
  const VaccineScreen({super.key, required this.baby});

  @override
  ConsumerState<VaccineScreen> createState() => _VaccineScreenState();
}

class _VaccineScreenState extends ConsumerState<VaccineScreen> {
  Future<void> _toggleVaccine(
    VaccineEntriesData? existing,
    _VaccineInfo info,
  ) async {
    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';

    if (existing != null) {
      // Delete – mark unvaccinated
      await db.deleteVaccineEntry(existing.id);
      ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
            modelType: 'vaccineEntry',
            modelId: existing.id,
            operation: SyncOperationType.delete,
            payload: {'id': existing.id},
          ));
    } else {
      // Insert – mark vaccinated
      final id = const Uuid().v4();
      final now = DateTime.now();
      await db.upsertVaccineEntry(VaccineEntriesCompanion(
        id: Value(id),
        babyId: Value(widget.baby.id),
        caregiverId: Value(caregiverId),
        timestamp: Value(now),
        vaccineKey: Value(info.key),
        administeredAt: Value(now),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
            modelType: 'vaccineEntry',
            modelId: id,
            operation: SyncOperationType.insert,
            payload: {
              'id': id,
              'babyId': widget.baby.id,
              'caregiverId': caregiverId,
              'vaccineKey': info.key,
              'administeredAt': now.toIso8601String(),
            },
          ));
    }
  }

  Future<void> _showAddCustomVaccineDialog() async {
    final nameController = TextEditingController();
    final lotController = TextEditingController();
    final providerController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Add Custom Vaccine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vaccine Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  subtitle: const Text('Date Administered'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: widget.baby.dateOfBirth,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => selectedDate = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lotController,
                  decoration: const InputDecoration(
                    labelText: 'Lot Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: providerController,
                  decoration: const InputDecoration(
                    labelText: 'Provider / Clinic',
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

    final db = ref.read(databaseProvider);
    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertVaccineEntry(VaccineEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiverId),
      timestamp: Value(selectedDate),
      customName: Value(name),
      administeredAt: Value(selectedDate),
      lotNumber:
          lotController.text.trim().isEmpty ? const Value.absent() : Value(lotController.text.trim()),
      provider:
          providerController.text.trim().isEmpty ? const Value.absent() : Value(providerController.text.trim()),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'vaccineEntry',
          modelId: id,
          operation: SyncOperationType.insert,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'caregiverId': caregiverId,
            'customName': name,
            'administeredAt': selectedDate.toIso8601String(),
            'lotNumber': lotController.text.trim(),
            'provider': providerController.text.trim(),
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final vaccineStream = db.select(db.vaccineEntries)
      ..where((v) => v.babyId.equals(widget.baby.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Vaccines')),
      body: StreamBuilder<List<VaccineEntriesData>>(
        stream: vaccineStream.watch(),
        builder: (context, snap) {
          final entries = snap.data ?? [];
          final completedKeys = {
            for (final e in entries)
              if (e.vaccineKey != null) e.vaccineKey!: e,
          };

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: _ageBands.map((band) {
              final bandVaccines =
                  _vaccineSchedule.where((v) => v.ageBand == band).toList();
              final completedInBand =
                  bandVaccines.where((v) => completedKeys.containsKey(v.key)).length;
              final progress =
                  bandVaccines.isEmpty ? 0.0 : completedInBand / bandVaccines.length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: progress,
                          color: progress == 1.0
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          trackColor: Colors.grey.withOpacity(0.2),
                        ),
                        child: Center(
                          child: Text(
                            '$completedInBand/${bandVaccines.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(band,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: progress == 1.0
                        ? const Text('Complete',
                            style: TextStyle(color: Colors.green, fontSize: 12))
                        : Text(
                            '$completedInBand of ${bandVaccines.length} done',
                            style: const TextStyle(fontSize: 12),
                          ),
                    children: bandVaccines.map((vaccine) {
                      final completed = completedKeys[vaccine.key];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: completed != null
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.1),
                          child: Icon(
                            completed != null
                                ? Icons.check
                                : Icons.circle_outlined,
                            size: 18,
                            color: completed != null
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        title: Text(vaccine.name),
                        subtitle: completed != null
                            ? Text(
                                DateFormat.yMMMd().format(completed.administeredAt),
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: completed != null
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 20)
                            : const Icon(Icons.radio_button_unchecked,
                                color: Colors.grey, size: 20),
                        onTap: () => _toggleVaccine(completed, vaccine),
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomVaccineDialog,
        icon: const Icon(Icons.add),
        label: const Text('Custom Vaccine'),
      ),
    );
  }
}
