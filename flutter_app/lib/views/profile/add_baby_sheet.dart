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

class AddBabySheet extends ConsumerStatefulWidget {
  final BabiesData? existing;
  const AddBabySheet({super.key, this.existing});

  @override
  ConsumerState<AddBabySheet> createState() => _AddBabySheetState();
}

class _AddBabySheetState extends ConsumerState<AddBabySheet> {
  final _nameCtrl = TextEditingController();
  DateTime _dob = DateTime.now().subtract(const Duration(days: 30));
  String _gender = 'other';
  bool _isPreterm = false;
  int _weeksGestation = 36;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final b = widget.existing!;
      _nameCtrl.text = b.name;
      _dob = b.dateOfBirth;
      _gender = b.gender;
      _isPreterm = b.isPreterm;
      _weeksGestation = b.weeksGestation ?? 36;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

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
              Text(widget.existing == null ? 'Add Baby' : 'Edit Baby',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Baby\'s name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of birth'),
                subtitle: Text(DateFormat.yMMMd().format(_dob)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dob,
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _dob = date);
                },
              ),
              const SizedBox(height: 8),
              Text('Gender', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Boy')),
                  ButtonSegment(value: 'female', label: Text('Girl')),
                  ButtonSegment(value: 'other', label: Text('Other')),
                ],
                selected: {_gender},
                onSelectionChanged: (s) => setState(() => _gender = s.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Born preterm'),
                value: _isPreterm,
                onChanged: (v) => setState(() => _isPreterm = v),
              ),
              if (_isPreterm) ...[
                Text('Weeks gestation: $_weeksGestation', style: theme.textTheme.bodyMedium),
                Slider(
                  value: _weeksGestation.toDouble(),
                  min: 24,
                  max: 39,
                  divisions: 15,
                  label: '$_weeksGestation weeks',
                  onChanged: (v) => setState(() => _weeksGestation = v.round()),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _nameCtrl.text.trim().isEmpty ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(widget.existing == null ? 'Add Baby' : 'Save Changes'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    HapticManager.success();

    final db = ref.read(databaseProvider);
    final sync = ref.read(syncManagerProvider.notifier);

    if (widget.existing != null) {
      await (db.update(db.babies)..where((b) => b.id.equals(widget.existing!.id))).write(BabiesCompanion(
        name: Value(name),
        dateOfBirth: Value(_dob),
        gender: Value(_gender),
        isPreterm: Value(_isPreterm),
        weeksGestation: Value(_isPreterm ? _weeksGestation : null),
        updatedAt: Value(DateTime.now()),
      ));
      sync.enqueue(SyncOperation(modelType: 'Baby', modelId: widget.existing!.id,
          operation: SyncOperationType.update, payload: {}));
    } else {
      final id = const Uuid().v4();
      await db.into(db.babies).insert(BabiesCompanion.insert(
        id: id, name: name, dateOfBirth: _dob, gender: _gender,
        isPreterm: Value(_isPreterm),
        weeksGestation: Value(_isPreterm ? _weeksGestation : null),
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      sync.enqueue(SyncOperation(modelType: 'Baby', modelId: id,
          operation: SyncOperationType.insert, payload: {}));
      ref.read(activeBabyIdProvider.notifier).state = id;
    }

    if (mounted) {
      showToast(widget.existing == null ? '${name} added!' : 'Updated', style: ToastStyle.success);
      Navigator.of(context).pop();
    }
  }
}
