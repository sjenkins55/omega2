import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../log/feed_log_sheet.dart';
import '../log/sleep_log_sheet.dart';
import '../log/diaper_log_sheet.dart';
import '../log/more_log_sheet.dart';

// ─── Age-appropriate wake window lookup ────────────────────────────────────────

Duration _wakeWindowFor(int ageMonths) {
  if (ageMonths < 2) return const Duration(hours: 1, minutes: 30);
  if (ageMonths < 4) return const Duration(hours: 1, minutes: 45);
  if (ageMonths < 6) return const Duration(hours: 2);
  if (ageMonths < 9) return const Duration(hours: 2, minutes: 30);
  if (ageMonths < 12) return const Duration(hours: 3);
  if (ageMonths < 18) return const Duration(hours: 3, minutes: 30);
  return const Duration(hours: 4);
}

// ─── Elapsed-time helper ───────────────────────────────────────────────────────

String _elapsed(DateTime? since) {
  if (since == null) return '—';
  final diff = DateTime.now().difference(since);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m ago';
  if (m > 0) return '${m}m ago';
  return 'Just now';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  bool _fabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);

    // Refresh every 60 seconds to keep elapsed times current.
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    HapticManager.selection();
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabController.reverse();
    }
  }

  Future<void> _openFeedSheet() async {
    _closeFab();
    final baby = ref.read(activeBabyProvider);
    if (baby == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FeedLogSheet(baby: baby),
    );
  }

  Future<void> _openSleepSheet() async {
    _closeFab();
    final baby = ref.read(activeBabyProvider);
    if (baby == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SleepLogSheet(baby: baby),
    );
  }

  Future<void> _openDiaperSheet() async {
    _closeFab();
    final baby = ref.read(activeBabyProvider);
    if (baby == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DiaperLogSheet(baby: baby),
    );
  }

  Future<void> _openMoreSheet() async {
    _closeFab();
    final baby = ref.read(activeBabyProvider);
    if (baby == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MoreLogSheet(baby: baby),
    );
  }

  @override
  Widget build(BuildContext context) {
    final babies = ref.watch(babiesStreamProvider).valueOrNull ?? [];
    final activeBabyId = ref.watch(activeBabyIdProvider);
    final baby = ref.watch(activeBabyProvider);
    final feeds = ref.watch(feedEntriesProvider).valueOrNull ?? [];
    final sleeps = ref.watch(sleepEntriesProvider).valueOrNull ?? [];
    final diapers = ref.watch(diaperEntriesProvider).valueOrNull ?? [];
    final cs = Theme.of(context).colorScheme;

    final lastFeed = feeds.isNotEmpty ? feeds.first : null;
    final lastDiaper = diapers.isNotEmpty ? diapers.first : null;

    // Find active sleep or last completed sleep.
    final activeSleep =
        sleeps.where((s) => s.isOngoing).firstOrNull;
    final lastSleep =
        activeSleep ?? (sleeps.isNotEmpty ? sleeps.first : null);

    // Wake window
    final ageMonths = baby?.ageInMonths ?? 3;
    final wakeWindow = _wakeWindowFor(ageMonths);
    Duration? awakeFor;
    if (activeSleep == null && lastSleep != null && lastSleep.endTime != null) {
      awakeFor = DateTime.now().difference(lastSleep.endTime!);
    } else if (activeSleep == null && lastSleep == null) {
      awakeFor = null;
    }

    // Today totals
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayFeeds =
        feeds.where((f) => f.timestamp.isAfter(todayStart)).toList();
    final todaySleeps =
        sleeps.where((s) => s.timestamp.isAfter(todayStart)).toList();
    final todayDiapers =
        diapers.where((d) => d.timestamp.isAfter(todayStart)).toList();

    Duration todaySleepTotal = Duration.zero;
    for (final s in todaySleeps) {
      final end = s.endTime ?? now;
      final start = s.startTime.isAfter(todayStart) ? s.startTime : todayStart;
      todaySleepTotal += end.difference(start);
    }

    return GestureDetector(
      onTap: _fabExpanded ? _closeFab : null,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                backgroundColor: cs.surface,
                title: baby != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(baby.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )),
                          Text(baby.ageLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      )
                    : const Text('Baby Tracker'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                ],
              ),

              // ── Baby switcher chips ───────────────────────────────────────
              if (babies.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: babies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final b = babies[i];
                        final isActive =
                            b.id == (activeBabyId ?? babies.first.id);
                        return FilterChip(
                          label: Text(b.name),
                          selected: isActive,
                          onSelected: (_) {
                            HapticManager.selection();
                            ref
                                .read(activeBabyIdProvider.notifier)
                                .state = b.id;
                          },
                          selectedColor: cs.primaryContainer,
                        );
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Status cards 2×2 ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _StatusCardGrid(
                    lastFeedTime: lastFeed?.timestamp,
                    awakeFor: awakeFor,
                    wakeWindow: wakeWindow,
                    isAsleep: activeSleep != null,
                    lastDiaperTime: lastDiaper?.timestamp,
                    todayFeedCount: todayFeeds.length,
                    todaySleepTotal: todaySleepTotal,
                    todayDiaperCount: todayDiapers.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Wake window progress ──────────────────────────────────────
              if (baby != null && awakeFor != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _WakeWindowCard(
                      awakeFor: awakeFor,
                      wakeWindow: wakeWindow,
                    ),
                  ),
                ),

              if (baby != null && awakeFor != null)
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Today summary ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _TodaySummarySection(
                    feedCount: todayFeeds.length,
                    sleepTotal: todaySleepTotal,
                    diaperCount: todayDiapers.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        floatingActionButton: _ExpandableFab(
          isExpanded: _fabExpanded,
          scaleAnimation: _fabScale,
          onToggle: _toggleFab,
          onFeed: _openFeedSheet,
          onSleep: _openSleepSheet,
          onDiaper: _openDiaperSheet,
          onMore: _openMoreSheet,
        ),
      ),
    );
  }
}

// ─── Status card grid ─────────────────────────────────────────────────────────

class _StatusCardGrid extends StatelessWidget {
  final DateTime? lastFeedTime;
  final Duration? awakeFor;
  final Duration wakeWindow;
  final bool isAsleep;
  final DateTime? lastDiaperTime;
  final int todayFeedCount;
  final Duration todaySleepTotal;
  final int todayDiaperCount;

  const _StatusCardGrid({
    required this.lastFeedTime,
    required this.awakeFor,
    required this.wakeWindow,
    required this.isAsleep,
    required this.lastDiaperTime,
    required this.todayFeedCount,
    required this.todaySleepTotal,
    required this.todayDiaperCount,
  });

  @override
  Widget build(BuildContext context) {
    final awakeStr = isAsleep
        ? 'Sleeping'
        : awakeFor != null
            ? _formatDuration(awakeFor!)
            : '—';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _StatusCard(
          label: 'Last Feed',
          value: _elapsed(lastFeedTime),
          icon: Icons.lunch_dining_outlined,
          color: EntryColors.feed,
        ),
        _StatusCard(
          label: isAsleep ? 'Sleeping' : 'Awake For',
          value: awakeStr,
          icon: isAsleep ? Icons.bedtime_outlined : Icons.wb_sunny_outlined,
          color: EntryColors.sleep,
        ),
        _StatusCard(
          label: 'Last Diaper',
          value: _elapsed(lastDiaperTime),
          icon: Icons.water_drop_outlined,
          color: EntryColors.diaper,
        ),
        _StatusCard(
          label: 'Today',
          value: '$todayFeedCount feeds · $todayDiaperCount diapers',
          icon: Icons.today_outlined,
          color: EntryColors.health,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatusCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wake window progress card ────────────────────────────────────────────────

class _WakeWindowCard extends StatelessWidget {
  final Duration awakeFor;
  final Duration wakeWindow;

  const _WakeWindowCard({
    required this.awakeFor,
    required this.wakeWindow,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (awakeFor.inSeconds / wakeWindow.inSeconds).clamp(0.0, 1.0);
    final Color barColor;
    if (progress < 0.6) {
      barColor = Colors.green;
    } else if (progress < 0.85) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.red;
    }

    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Wake Window',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                Text(
                  '${_formatDuration(awakeFor)} / ${_formatDuration(wakeWindow)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress >= 1.0
                  ? 'Time for a nap!'
                  : progress >= 0.85
                      ? 'Getting sleepy soon…'
                      : 'Well-rested',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Today summary section ────────────────────────────────────────────────────

class _TodaySummarySection extends StatelessWidget {
  final int feedCount;
  final Duration sleepTotal;
  final int diaperCount;

  const _TodaySummarySection({
    required this.feedCount,
    required this.sleepTotal,
    required this.diaperCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Summary",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryChip(
              icon: Icons.lunch_dining_outlined,
              color: EntryColors.feed,
              label: '$feedCount feed${feedCount == 1 ? '' : 's'}',
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              icon: Icons.bedtime_outlined,
              color: EntryColors.sleep,
              label: _formatDuration(sleepTotal),
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              icon: Icons.water_drop_outlined,
              color: EntryColors.diaper,
              label: '$diaperCount diaper${diaperCount == 1 ? '' : 's'}',
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Expandable FAB ───────────────────────────────────────────────────────────

class _ExpandableFab extends StatelessWidget {
  final bool isExpanded;
  final Animation<double> scaleAnimation;
  final VoidCallback onToggle;
  final VoidCallback onFeed;
  final VoidCallback onSleep;
  final VoidCallback onDiaper;
  final VoidCallback onMore;

  const _ExpandableFab({
    required this.isExpanded,
    required this.scaleAnimation,
    required this.onToggle,
    required this.onFeed,
    required this.onSleep,
    required this.onDiaper,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs (shown when expanded)
        ScaleTransition(
          scale: scaleAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniFabItem(
                label: 'More',
                icon: Icons.more_horiz,
                color: Colors.grey.shade700,
                onTap: onMore,
              ),
              const SizedBox(height: 12),
              _MiniFabItem(
                label: 'Diaper',
                icon: Icons.water_drop_outlined,
                color: EntryColors.diaper,
                onTap: onDiaper,
              ),
              const SizedBox(height: 12),
              _MiniFabItem(
                label: 'Sleep',
                icon: Icons.bedtime_outlined,
                color: EntryColors.sleep,
                onTap: onSleep,
              ),
              const SizedBox(height: 12),
              _MiniFabItem(
                label: 'Feed',
                icon: Icons.lunch_dining_outlined,
                color: EntryColors.feed,
                onTap: onFeed,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: onToggle,
          child: AnimatedRotation(
            turns: isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 280),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _MiniFabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniFabItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
          ),
        ),
        const SizedBox(width: 10),
        // Circle button
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(102),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
