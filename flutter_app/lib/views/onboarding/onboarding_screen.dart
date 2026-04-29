import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/haptics.dart';
import '../../database/app_database.dart';
import '../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Baby info
  final _babyNameCtrl = TextEditingController();
  DateTime _dob = DateTime.now().subtract(const Duration(days: 7));
  String _gender = 'other';
  bool _isPreterm = false;

  // Caregiver info
  final _caregiverNameCtrl = TextEditingController();
  String _selectedEmoji = '🧑';

  final _emojis = ['👩', '👨', '👵', '👴', '👩‍⚕️', '👨‍⚕️', '🧑', '👶'];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _babyNameCtrl.dispose();
    _caregiverNameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 3) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() => _page++);
    }
  }

  void _back() {
    if (_page > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() => _page--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_page > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                  padding: const EdgeInsets.all(16),
                ),
              )
            else
              const SizedBox(height: 16),
            LinearProgressIndicator(value: (_page + 1) / 4),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onStart: _next),
                  _BabySetupPage(
                    nameCtrl: _babyNameCtrl,
                    dob: _dob,
                    gender: _gender,
                    isPreterm: _isPreterm,
                    onDobChanged: (d) => setState(() => _dob = d),
                    onGenderChanged: (g) => setState(() => _gender = g),
                    onPretrmChanged: (v) => setState(() => _isPreterm = v),
                    onNext: _babyNameCtrl.text.trim().isNotEmpty ? _next : null,
                  ),
                  _CaregiverPage(
                    nameCtrl: _caregiverNameCtrl,
                    selectedEmoji: _selectedEmoji,
                    emojis: _emojis,
                    onEmojiSelected: (e) => setState(() => _selectedEmoji = e),
                    onNext: _caregiverNameCtrl.text.trim().isNotEmpty ? _next : null,
                  ),
                  _PermissionsPage(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    HapticManager.success();
    final db = ref.read(databaseProvider);
    final babyId = const Uuid().v4();
    final caregiverId = const Uuid().v4();
    final accessId = const Uuid().v4();
    final now = DateTime.now();

    await db.into(db.babies).insert(BabiesCompanion.insert(
      id: babyId,
      name: _babyNameCtrl.text.trim(),
      dateOfBirth: _dob,
      gender: _gender,
      isPreterm: Value(_isPreterm),
      createdAt: now,
      updatedAt: now,
    ));

    await db.into(db.caregivers).insert(CaregiversCompanion.insert(
      id: caregiverId,
      displayName: '${_selectedEmoji} ${_caregiverNameCtrl.text.trim()}',
      isCurrentDevice: const Value(true),
      role: 'admin',
      createdAt: now,
      updatedAt: now,
    ));

    await db.into(db.babyAccessTable).insert(BabyAccessTableCompanion.insert(
      id: accessId,
      babyId: babyId,
      caregiverId: caregiverId,
      role: 'admin',
      createdAt: now,
      updatedAt: now,
    ));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);

    ref.read(activeBabyIdProvider.notifier).state = babyId;
    ref.read(hasCompletedOnboardingProvider.notifier).state = true;
  }
}

// ─── Pages ────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomePage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6B7FD7), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 32),
          Text('Baby Tracker', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Track everything. Miss nothing. Built for families.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(minimumSize: const Size(240, 52)),
            child: const Text('Get Started', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _BabySetupPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final DateTime dob;
  final String gender;
  final bool isPreterm;
  final ValueChanged<DateTime> onDobChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<bool> onPretrmChanged;
  final VoidCallback? onNext;

  const _BabySetupPage({
    required this.nameCtrl, required this.dob, required this.gender,
    required this.isPreterm, required this.onDobChanged, required this.onGenderChanged,
    required this.onPretrmChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tell us about your baby", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Baby\'s name'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(DateFormat.yMMMd().format(dob)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: dob,
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                lastDate: DateTime.now(),
              );
              if (d != null) onDobChanged(d);
            },
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Boy')),
              ButtonSegment(value: 'female', label: Text('Girl')),
              ButtonSegment(value: 'other', label: Text('Other')),
            ],
            selected: {gender},
            onSelectionChanged: (s) => onGenderChanged(s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Born preterm'),
            value: isPreterm,
            onChanged: onPretrmChanged,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _CaregiverPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String selectedEmoji;
  final List<String> emojis;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onNext;

  const _CaregiverPage({required this.nameCtrl, required this.selectedEmoji,
      required this.emojis, required this.onEmojiSelected, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Who are you?", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(child: Text(selectedEmoji, style: const TextStyle(fontSize: 64))),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 8,
            children: emojis.map((e) => GestureDetector(
              onTap: () => onEmojiSelected(e),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: e == selectedEmoji
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: e == selectedEmoji
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : null,
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {},
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _PermissionsPage extends ConsumerWidget {
  final VoidCallback onFinish;
  const _PermissionsPage({required this.onFinish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 64, color: Colors.indigo),
          const SizedBox(height: 24),
          Text('Stay on schedule', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Allow notifications to get feed reminders, diaper alerts, and medication reminders.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(notificationServiceProvider).requestPermission();
              onFinish();
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('Allow Notifications'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onFinish,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}
