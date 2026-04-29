import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/toast.dart';

class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  int _selectedIndex = 1; // default annual
  bool _loading = false;

  static const _offers = [
    _Offer('Monthly', '\$2.99', '/month', false),
    _Offer('Annual', '\$19.99', '/year · Save 44%', true),
  ];

  static const _features = [
    _Feature(Icons.child_friendly_rounded, 'Unlimited babies', 'Track multiple children'),
    _Feature(Icons.people_rounded, 'Unlimited caregivers', 'Share with family and caregivers'),
    _Feature(Icons.bar_chart_rounded, 'Insights & trends', 'Detailed charts and analytics'),
    _Feature(Icons.upload_rounded, 'Data export', 'Export as CSV or PDF'),
    _Feature(Icons.widgets_rounded, 'Home screen widgets', 'Quick glance without opening app (iOS)'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Center(child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6B7FD7), Color(0xFF9C27B0)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                )),
                const SizedBox(height: 16),
                Text('Go Premium', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Everything you need to track your baby\'s growth.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ..._features.map((f) => ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6B7FD7), Color(0xFF9C27B0)]),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(f.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(f.subtitle),
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                )),
                const SizedBox(height: 24),
                ...List.generate(_offers.length, (i) {
                  final o = _offers[i];
                  final selected = _selectedIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
                      ),
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (o.isBestValue)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text('Most Popular', style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          Text(o.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(o.sublabel, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ]),
                        const Spacer(),
                        Text(o.price, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                FilledButton(
                  onPressed: _loading ? null : _subscribe,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Start Premium', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: _restore, child: const Text('Restore', style: TextStyle(fontSize: 12))),
                  const Text('·', style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: () {}, child: const Text('Privacy', style: TextStyle(fontSize: 12))),
                  const Text('·', style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: () {}, child: const Text('Terms', style: TextStyle(fontSize: 12))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    await ref.read(subscriptionProvider.notifier).purchase();
    setState(() => _loading = false);
    if (mounted) {
      showToast('Welcome to Premium!', style: ToastStyle.success);
      Navigator.of(context).pop();
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await ref.read(subscriptionProvider.notifier).restore();
    setState(() => _loading = false);
    if (mounted) {
      final isPremium = ref.read(subscriptionProvider) == SubscriptionTier.premium;
      showToast(isPremium ? 'Premium restored!' : 'No active subscription found', style: isPremium ? ToastStyle.success : ToastStyle.info);
    }
  }
}

class _Offer {
  final String label;
  final String price;
  final String sublabel;
  final bool isBestValue;
  const _Offer(this.label, this.price, this.sublabel, this.isBestValue);
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
}
