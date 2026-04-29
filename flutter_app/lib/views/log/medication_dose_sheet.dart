import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';
import '../../widgets/toast.dart';

class MedicationDoseSheet extends ConsumerStatefulWidget {
  final BabiesData baby;
  const MedicationDoseSheet({super.key, required this.baby});

  @override
  ConsumerState<MedicationDoseSheet> createState() => _MedicationDoseSheetState();
}

class _MedicationDoseSheetState extends ConsumerState<MedicationDoseSheet> {
  String? _selectedMedId;
  bool _skipped = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medsAsync = ref.watch(medicationsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Log Medication Dose', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              medsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (meds) {
                  final active = meds.where((m) => m.isActive).toList();
                  if (active.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 12),
                          Expanded(child: Text('No active medications.\nAdd one in Profile → Health → Medications.')),
                        ],
                      ),
                    );
                  }
                  if (_selectedMedId == null && active.length == 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) =>
                        setState(() => _selectedMedId = active.first.id));
                  }
                  return Column(
                    children: active.map((med) {
                      final selected = _selectedMedId == med.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMedId = med.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.medication_rounded, color: selected ? theme.colorScheme.primary : Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(med.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  Text('${med.dose} ${med.doseUnit} · ${med.route}', style: theme.textTheme.bodySmall),
                                  if (med.frequencyHours != null)
                                    Text('Every ${med.frequencyHours!.toInt()}h', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                ]),
                              ),
                              if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Dose was skipped'),
                value: _skipped,
                onChanged: (v) => setState(() => _skipped = v),
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _selectedMedId == null ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Save Dose'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    HapticManager.success();
    final db = ref.read(databaseProvider);
    final caregiver = await db.getCurrentCaregiver();
    final sync = ref.read(syncManagerProvider.notifier);
    final id = const Uuid().v4();

    await db.into(db.medicationDoses).insert(MedicationDosesCompanion.insert(
      id: id,
      medicationId: _selectedMedId!,
      caregiverId: caregiver?.id ?? const Uuid().v4(),
      administeredAt: DateTime.now(),
      skipped: _skipped,
      notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
    ));

    sync.enqueue(SyncOperation(
      modelType: 'MedicationDose', modelId: id,
      operation: SyncOperationType.insert,
      payload: {'medication_id': _selectedMedId, 'skipped': _skipped},
    ));

    if (mounted) {
      showToast(_skipped ? 'Dose marked as skipped' : 'Dose recorded', style: ToastStyle.success);
      Navigator.of(context).pop();
    }
  }
}
