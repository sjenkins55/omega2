import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';
import '../../widgets/toast.dart';

class TemperatureLogSheet extends ConsumerStatefulWidget {
  final BabiesData baby;
  const TemperatureLogSheet({super.key, required this.baby});

  @override
  ConsumerState<TemperatureLogSheet> createState() => _TemperatureLogSheetState();
}

class _TemperatureLogSheetState extends ConsumerState<TemperatureLogSheet> {
  double _valueFahrenheit = 98.6;
  String _method = 'axillary';
  bool _useCelsius = false;
  final _methods = ['axillary', 'rectal', 'oral', 'temporal', 'tympanic'];
  final _methodLabels = ['Axillary', 'Rectal', 'Oral', 'Temporal', 'Tympanic'];

  bool get _isFever => _valueFahrenheit >= 100.4;

  double get _displayValue =>
      _useCelsius ? (_valueFahrenheit - 32) * 5 / 9 : _valueFahrenheit;

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
            children: [
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Temperature', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() => _useCelsius = !_useCelsius),
                    child: Text(_useCelsius ? '°F' : '°C'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: _isFever ? Colors.red.shade50 : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_displayValue.toStringAsFixed(1)}°${_useCelsius ? 'C' : 'F'}',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: _isFever ? Colors.red : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (_isFever)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: const Text('FEVER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _valueFahrenheit,
                min: 96.0,
                max: 106.0,
                divisions: 100,
                activeColor: _isFever ? Colors.red : theme.colorScheme.primary,
                onChanged: (v) {
                  setState(() => _valueFahrenheit = v);
                  if (_isFever) HapticManager.warning();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('96°F', style: theme.textTheme.labelSmall),
                  Text('106°F', style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 20),
              Text('Method', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(_methods.length, (i) => ChoiceChip(
                  label: Text(_methodLabels[i]),
                  selected: _method == _methods[i],
                  onSelected: (_) => setState(() => _method = _methods[i]),
                )),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Save Temperature'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isFever) HapticManager.error();
    else HapticManager.success();

    final db = ref.read(databaseProvider);
    final caregiver = await db.getCurrentCaregiver();
    final sync = ref.read(syncManagerProvider.notifier);
    final id = const Uuid().v4();

    await db.into(db.temperatureEntries).insert(TemperatureEntriesCompanion.insert(
      id: id,
      babyId: widget.baby.id,
      caregiverId: caregiver?.id ?? const Uuid().v4(),
      timestamp: DateTime.now(),
      valueFahrenheit: _valueFahrenheit,
      method: _method,
    ));

    sync.enqueue(SyncOperation(
      modelType: 'TemperatureEntry', modelId: id,
      operation: SyncOperationType.insert,
      payload: {'baby_id': widget.baby.id, 'value_fahrenheit': _valueFahrenheit, 'method': _method},
    ));

    if (mounted) {
      showToast(_isFever ? 'Fever recorded — ${_valueFahrenheit.toStringAsFixed(1)}°F' : 'Temperature saved',
          style: _isFever ? ToastStyle.warning : ToastStyle.success);
      Navigator.of(context).pop();
    }
  }
}
