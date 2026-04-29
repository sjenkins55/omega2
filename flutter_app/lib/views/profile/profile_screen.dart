import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/paywall.dart';
import 'add_baby_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babiesAsync = ref.watch(babiesStreamProvider);
    final activeBaby = ref.watch(activeBabyProvider);
    final syncState = ref.watch(syncManagerProvider);
    final sub = ref.watch(subscriptionProvider);
    final caregiver = ref.watch(currentCaregiverProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => _showAddBaby(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Babies ──────────────────────────────────────────────────────────
          _SectionHeader('Babies'),
          babiesAsync.when(
            loading: () => const ListTile(title: Text('Loading…')),
            error: (e, _) => ListTile(title: Text('Error: $e')),
            data: (babies) => Column(
              children: [
                ...babies.map((b) => ListTile(
                  leading: _BabyAvatar(baby: b),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_ageLabel(b)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (b.id == activeBaby?.id)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ]),
                  onTap: () => ref.read(activeBabyIdProvider.notifier).state = b.id,
                  onLongPress: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => AddBabySheet(existing: b),
                  ),
                )),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add)),
                  title: const Text('Add baby'),
                  subtitle: sub == SubscriptionTier.free
                      ? Text('${babies.length} / 1 on free plan')
                      : null,
                  onTap: () {
                    if (sub.canAddBaby(babies.length)) {
                      _showAddBaby(context);
                    } else {
                      _showPaywall(context);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Your Family ──────────────────────────────────────────────────────
          _SectionHeader('Your Family'),
          if (caregiver != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(caregiver.displayName),
              subtitle: Text(caregiver.role),
              trailing: caregiver.supabaseUserId != null
                  ? const Icon(Icons.verified, color: Colors.green)
                  : null,
            ),
          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: const Text('Manage Caregivers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // ── Health & Growth ───────────────────────────────────────────────────
          if (activeBaby != null) ...[
            _SectionHeader('Health & Growth'),
            _HealthNavTile('Growth Charts',    Icons.show_chart,         '/health/growth',       activeBaby, context),
            _HealthNavTile('Vaccine Schedule', Icons.vaccines_outlined,  '/health/vaccines',     activeBaby, context),
            _HealthNavTile('Milestones',       Icons.star_outline,       '/health/milestones',   activeBaby, context),
            _HealthNavTile('Medications',      Icons.medication_rounded, '/health/medications',  activeBaby, context),
            _HealthNavTile('Illness Log',      Icons.sick_rounded,       '/health/illness',      activeBaby, context),
            _HealthNavTile('Appointments',     Icons.calendar_month,     '/health/appointments', activeBaby, context),
          ],

          // ── Sync & Account ────────────────────────────────────────────────────
          _SectionHeader('Sync & Account'),
          ListTile(
            leading: Icon(syncState.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: syncState.isOnline ? Colors.green : Colors.orange),
            title: Text(syncState.isOnline ? 'Online' : 'Offline'),
            subtitle: syncState.pendingCount > 0
                ? Text('${syncState.pendingCount} changes pending sync')
                : const Text('All synced'),
          ),
          if (caregiver?.supabaseUserId == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in with Apple'),
              subtitle: const Text('Sync data across devices'),
              onTap: () {},
            ),

          // ── Settings ──────────────────────────────────────────────────────────
          _SectionHeader('Settings'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Units & Display'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export Data'),
            trailing: sub == SubscriptionTier.free
                ? const Icon(Icons.lock_outline, size: 18)
                : const Icon(Icons.chevron_right),
            onTap: sub == SubscriptionTier.premium ? () {} : () => _showPaywall(context),
          ),

          // ── App ───────────────────────────────────────────────────────────────
          _SectionHeader('App'),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Baby Tracker',
            applicationVersion: '1.0.0',
            dense: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAddBaby(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddBabySheet(),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaywallSheet(),
    );
  }

  String _ageLabel(BabiesData b) {
    final months = _monthsBetween(b.dateOfBirth, DateTime.now());
    if (months < 1) return '${DateTime.now().difference(b.dateOfBirth).inDays}d old';
    if (months < 24) return '${months}mo old';
    return '${months ~/ 12}y old';
  }

  int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + to.month - from.month;

  Widget _HealthNavTile(String title, IconData icon, String route, BabiesData baby, BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route, arguments: baby),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
  );
}

class _BabyAvatar extends StatelessWidget {
  final BabiesData baby;
  const _BabyAvatar({required this.baby});

  @override
  Widget build(BuildContext context) {
    final color = baby.gender == 'male' ? Colors.blue
        : baby.gender == 'female' ? Colors.pink : Colors.purple;
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Text(baby.name.isNotEmpty ? baby.name[0].toUpperCase() : '?',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

extension on SubscriptionTier {
  bool canAddBaby(int count) =>
      this == SubscriptionTier.premium || count < 1;
}
