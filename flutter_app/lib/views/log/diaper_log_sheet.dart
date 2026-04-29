import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../database/app_database.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';
import '../log/feed_log_sheet.dart' show databaseProvider;

// ─── Diaper type config ───────────────────────────────────────────────────────

class _DiaperTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _DiaperTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _diaperTypes = [
  _DiaperTypeOption(
    value: 'wet',
    label: 'Wet',
    icon: Icons.water_drop,
    color: Color(0xFF4FC3F7),
  ),
  _DiaperTypeOption(
    value: 'dirty',
    label: 'Dirty',
    icon: Icons.circle,
    color: Color(0xFF8D6E63),
  ),
  _DiaperTypeOption(
    value: 'both',
    label: 'Both',
    icon: Icons.blur_circular,
    color: EntryColors.diaper,
  ),
  _DiaperTypeOption(
    value: 'dry',
    label: 'Dry',
    icon: Icons.air,
    color: Colors.grey,
  ),
];

// ─── Stool color config ───────────────────────────────────────────────────────

class _StoolColorOption {
  final String value;
  final String label;
  final Color color;
  final bool isAlert;

  const _StoolColorOption({
    required this.value,
    required this.label,
    required this.color,
    this.isAlert = false,
  });
}

const _stoolColors = [
  _StoolColorOption(value: 'yellow', label: 'Yellow', color: Color(0xFFFFF176)),
  _StoolColorOption(value: 'green', label: 'Green', color: Color(0xFF81C784)),
  _StoolColorOption(value: 'brown', label: 'Brown', color: Color(0xFF8D6E63)),
  _StoolColorOption(value: 'orange', label: 'Orange', color: Color(0xFFFFB74D)),
  _StoolColorOption(
      value: 'red', label: 'Red', color: Color(0xFFEF5350), isAlert: true),
  _StoolColorOption(
      value: 'black', label: 'Black', color: Color(0xFF212121), isAlert: true),
  _StoolColorOption(
      value: 'white', label: 'White', color: Color(0xFFF5F5F5), isAlert: true),
  _StoolColorOption(value: 'other', label: 'Other', color: Color(0xFFBDBDBD)),
];

// ─── Diaper Log Sheet ─────────────────────────────────────────────────────────

class DiaperLogSheet extends ConsumerStatefulWidget {
  final BabiesData baby;

  const DiaperLogSheet({super.key, required this.baby});

  @override
  ConsumerState<DiaperLogSheet> createState() => _DiaperLogSheetState();
}

class _DiaperLogSheetState extends ConsumerState<DiaperLogSheet> {
  String _selectedType = 'wet';
  String? _selectedColor;
  bool _hasRash = false;
  bool _saving = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _showColorPicker =>
      _selectedType == 'dirty' || _selectedType == 'both';

  void _selectColor(String color) {
    // Check if it's a warning color
    final option = _stoolColors.firstWhere((c) => c.value == color);
    if (option.isAlert) {
      HapticManager.warning();
      _showAlertDialog(color);
    } else {
      HapticManager.selection();
    }
    setState(() => _selectedColor = color);
  }

  void _showAlertDialog(String color) {
    final messages = {
      'red': 'Red stool may indicate blood. Consider contacting your pediatrician.',
      'black': 'Black tarry stool (after newborn stage) may indicate bleeding in the digestive tract. Contact your pediatrician.',
      'white': 'Pale white stool may indicate a liver or bile duct issue. Contact your pediatrician promptly.',
    };
    final msg = messages[color] ?? 'This color may warrant medical attention.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 36),
        title: const Text('Note About Stool Color'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    HapticManager.success();
    setState(() => _saving = true);

    final caregiver = await ref.read(currentCaregiverProvider.future);
    if (caregiver == null) {
      setState(() => _saving = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    await db.upsertDiaperEntry(DiaperEntriesCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiver.id),
      timestamp: Value(now),
      diaperType: Value(_selectedType),
      stoolColor: Value(_showColorPicker ? _selectedColor : null),
      hasRash: Value(_hasRash),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'diaper_entry',
          modelId: id,
          operation: SyncOperationType.insert,
        ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EntryColors.diaper.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.water_drop_outlined,
                          color: EntryColors.diaper, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Log Diaper',
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

              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type selector
                      Text('Type',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              )),
                      const SizedBox(height: 12),
                      _DiaperTypeGrid(
                        selected: _selectedType,
                        onSelect: (v) {
                          HapticManager.selection();
                          setState(() {
                            _selectedType = v;
                            if (v == 'wet' || v == 'dry') {
                              _selectedColor = null;
                            }
                          });
                        },
                      ),

                      // Color picker
                      if (_showColorPicker) ...[
                        const SizedBox(height: 24),
                        Text('Stool Color',
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    )),
                        const SizedBox(height: 12),
                        _StoolColorGrid(
                          selected: _selectedColor,
                          onSelect: _selectColor,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Rash toggle
                      Card(
                        color: _hasRash
                            ? Colors.red.withAlpha(26)
                            : cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: SwitchListTile.adaptive(
                          value: _hasRash,
                          onChanged: (v) {
                            if (v) HapticManager.warning();
                            setState(() => _hasRash = v);
                          },
                          title: const Text('Diaper Rash'),
                          secondary: Icon(
                            Icons.warning_amber_outlined,
                            color: _hasRash ? Colors.red : cs.onSurfaceVariant,
                          ),
                          activeColor: Colors.red,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                        ),
                      ),

                      const SizedBox(height: 16),

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
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: EntryColors.diaper,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Diaper',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Diaper type tile grid ────────────────────────────────────────────────────

class _DiaperTypeGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _DiaperTypeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: _diaperTypes.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? opt.color.withAlpha(51)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? opt.color : cs.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(opt.icon, color: isSelected ? opt.color : cs.onSurfaceVariant, size: 28),
                const SizedBox(height: 6),
                Text(
                  opt.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected ? opt.color : cs.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Stool color swatches ─────────────────────────────────────────────────────

class _StoolColorGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _StoolColorGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: _stoolColors.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.value),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: opt.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : opt.isAlert
                            ? Colors.red.withAlpha(153)
                            : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 3 : opt.isAlert ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(77),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: opt.isAlert
                    ? const Icon(Icons.warning_amber,
                        color: Colors.red, size: 18)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                opt.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: opt.isAlert ? Colors.red : null,
                      fontWeight: isSelected ? FontWeight.w700 : null,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
