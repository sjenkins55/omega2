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

class AppointmentScreen extends ConsumerWidget {
  final BabiesData? baby;
  const AppointmentScreen({super.key, this.baby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBaby = baby ?? ref.watch(activeBabyProvider);
    if (activeBaby == null) return const Scaffold(body: Center(child: Text('No baby selected')));

    final apptAsync = ref.watch(appointmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments'), centerTitle: false),
      body: apptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (appts) {
          final now = DateTime.now();
          final upcoming = appts.where((a) => a.scheduledAt.isAfter(now)).toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          final past = appts.where((a) => !a.scheduledAt.isAfter(now)).toList()
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          if (appts.isEmpty) {
            return _EmptyState(onAdd: () => _showAddSheet(context, activeBaby));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionHeader('Upcoming'),
                ...upcoming.map((a) => _AppointmentTile(appt: a, babyName: activeBaby.name,
                    onEdit: () => _showAddSheet(context, activeBaby, existing: a),
                    onDelete: () => _confirmDelete(context, ref, a))),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader('Past'),
                ...past.map((a) => _AppointmentTile(appt: a, babyName: activeBaby.name,
                    onEdit: () => _showAddSheet(context, activeBaby, existing: a),
                    onDelete: () => _confirmDelete(context, ref, a))),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, activeBaby),
        icon: const Icon(Icons.add),
        label: const Text('Add Appointment'),
      ),
    );
  }

  void _showAddSheet(BuildContext context, BabiesData baby, {AppointmentsData? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddAppointmentSheet(baby: baby, existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppointmentsData appt) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete appointment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = ref.read(databaseProvider);
              await (db.delete(db.appointments)..where((a) => a.id.equals(appt.id))).go();
              ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
                modelType: 'Appointment', modelId: appt.id, operation: SyncOperationType.delete,
                payload: {'remoteId': appt.remoteId},
              ));
              showToast('Appointment deleted', style: ToastStyle.info);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('No appointments yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Schedule well visits, sick visits, and specialist appointments.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Appointment')),
    ]),
  );
}

class _AppointmentTile extends StatelessWidget {
  final AppointmentsData appt;
  final String babyName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AppointmentTile({required this.appt, required this.babyName, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isUpcoming = appt.scheduledAt.isAfter(now);
    final days = appt.scheduledAt.difference(now).inDays.abs();
    final typeIcon = switch (appt.appointmentType) {
      'wellVisit'   => Icons.favorite_outline_rounded,
      'sick'        => Icons.thermostat,
      'specialist'  => Icons.medical_services_outlined,
      _             => Icons.calendar_today_outlined,
    };
    return Dismissible(
      key: ValueKey(appt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: (isUpcoming ? Colors.blue : Colors.grey).withOpacity(0.12),
            child: Icon(typeIcon, color: isUpcoming ? Colors.blue : Colors.grey),
          ),
          title: Text(appt.appointmentType.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)!}').trim().capitalize()),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (appt.provider != null) Text(appt.provider!),
            Text(DateFormat.MMMd().add_jm().format(appt.scheduledAt)),
          ]),
          trailing: isUpcoming
              ? Chip(label: Text(days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'In ${days}d'),
                  backgroundColor: Colors.blue.withOpacity(0.1))
              : null,
          onTap: onEdit,
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─── Add / Edit Sheet ─────────────────────────────────────────────────────────

class _AddAppointmentSheet extends ConsumerStatefulWidget {
  final BabiesData baby;
  final AppointmentsData? existing;
  const _AddAppointmentSheet({required this.baby, this.existing});

  @override
  ConsumerState<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends ConsumerState<_AddAppointmentSheet> {
  final _providerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 7));
  String _type = 'wellVisit';
  bool _setReminder = true;

  final _types = ['wellVisit', 'sick', 'specialist', 'other'];
  final _typeLabels = ['Well Visit', 'Sick Visit', 'Specialist', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _scheduledAt = e.scheduledAt;
      _type = e.appointmentType;
      _providerCtrl.text = e.provider ?? '';
      _notesCtrl.text = e.notes ?? '';
    }
  }

  @override
  void dispose() { _providerCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text(widget.existing == null ? 'Add Appointment' : 'Edit Appointment',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Type', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(_types.length, (i) => ChoiceChip(
                  label: Text(_typeLabels[i]),
                  selected: _type == _types[i],
                  onSelected: (_) => setState(() => _type = _types[i]),
                )),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & Time'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(_scheduledAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context, initialDate: _scheduledAt,
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date == null || !mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt));
                  if (time == null || !mounted) return;
                  setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: _providerCtrl, decoration: const InputDecoration(labelText: 'Provider / Doctor (optional)')),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set reminder'),
                value: _setReminder,
                onChanged: (v) => setState(() => _setReminder = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Save Appointment'),
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

    if (widget.existing != null) {
      await (db.update(db.appointments)..where((a) => a.id.equals(widget.existing!.id))).write(AppointmentsCompanion(
        scheduledAt: Value(_scheduledAt),
        appointmentType: Value(_type),
        provider: Value(_providerCtrl.text.isEmpty ? null : _providerCtrl.text),
        notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
        updatedAt: Value(DateTime.now()),
      ));
      sync.enqueue(SyncOperation(modelType: 'Appointment', modelId: widget.existing!.id,
          operation: SyncOperationType.update, payload: {}));
    } else {
      final id = const Uuid().v4();
      await db.into(db.appointments).insert(AppointmentsCompanion.insert(
        id: id, babyId: widget.baby.id, caregiverId: caregiver?.id ?? const Uuid().v4(),
        timestamp: _scheduledAt, scheduledAt: _scheduledAt, appointmentType: _type,
        provider: Value(_providerCtrl.text.isEmpty ? null : _providerCtrl.text),
        notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
      ));
      sync.enqueue(SyncOperation(modelType: 'Appointment', modelId: id,
          operation: SyncOperationType.insert, payload: {}));
    }

    if (mounted) {
      showToast('Appointment saved', style: ToastStyle.success);
      Navigator.pop(context);
    }
  }
}
