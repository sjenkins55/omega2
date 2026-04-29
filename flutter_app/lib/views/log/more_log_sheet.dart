import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import 'temperature_log_sheet.dart';
import 'medication_dose_sheet.dart';
import 'quick_note_sheet.dart';

class MoreLogSheet extends ConsumerWidget {
  final BabiesData baby;
  const MoreLogSheet({super.key, required this.baby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Log for ${baby.name}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          _MoreTile(icon: Icons.thermostat, color: Colors.red, title: 'Temperature', subtitle: 'Log a temp reading',
            onTap: () => _openSheet(context, TemperatureLogSheet(baby: baby))),
          _MoreTile(icon: Icons.medication_rounded, color: Colors.purple, title: 'Medication Dose', subtitle: 'Mark a dose as given',
            onTap: () => _openSheet(context, MedicationDoseSheet(baby: baby))),
          _MoreTile(icon: Icons.note_alt_outlined, color: Colors.grey, title: 'Quick Note', subtitle: 'Handoff note for next caregiver',
            onTap: () => _openSheet(context, QuickNoteSheet(baby: baby))),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Health', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
            ),
          ),
          _MoreTile(icon: Icons.sick_rounded, color: Colors.orange, title: 'Illness', subtitle: 'Track symptoms and duration',
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/health/illness', arguments: baby); }),
          _MoreTile(icon: Icons.calendar_month_rounded, color: Colors.blue, title: 'Appointment', subtitle: 'Schedule or log a visit',
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/health/appointments', arguments: baby); }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MoreTile({required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
