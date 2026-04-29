import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../database/app_database.dart';
import '../../providers/providers.dart';

enum _InsightRange { week, month, quarter }

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _InsightRange _range = _InsightRange.week;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  int get _days => switch (_range) {
    _InsightRange.week    => 7,
    _InsightRange.month   => 30,
    _InsightRange.quarter => 90,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Feed'), Tab(text: 'Sleep'), Tab(text: 'Diaper'),
        ]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_InsightRange>(
              segments: const [
                ButtonSegment(value: _InsightRange.week, label: Text('7 days')),
                ButtonSegment(value: _InsightRange.month, label: Text('30 days')),
                ButtonSegment(value: _InsightRange.quarter, label: Text('90 days')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _FeedInsights(days: _days),
              _SleepInsights(days: _days),
              _DiaperInsights(days: _days),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Feed Tab ─────────────────────────────────────────────────────────────────

class _FeedInsights extends ConsumerWidget {
  final int days;
  const _FeedInsights({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedsAsync = ref.watch(feedEntriesProvider);
    return feedsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (feeds) {
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final recent = feeds.where((f) => f.timestamp.isAfter(cutoff)).toList();
        final byDay = _groupByDay(recent, days, (f) {
          if (f.feedType == 'breast') return ((f.leftDurationSeconds ?? 0) + (f.rightDurationSeconds ?? 0)) / 60.0;
          if (f.feedType == 'bottle') return f.amountMl ?? 0;
          return 1.0;
        });
        final avg = byDay.isEmpty ? 0.0 : byDay.values.reduce((a, b) => a + b) / byDay.length;
        return _InsightLayout(
          stats: [
            _StatCard('Today\'s feeds', '${recent.where(_isToday).length}', icon: Icons.local_dining),
            _StatCard('Avg per day', avg.toStringAsFixed(1), icon: Icons.trending_up),
          ],
          chart: _BarChartWidget(data: byDay, color: EntryColors.feed, unit: 'min/ml'),
        );
      },
    );
  }
}

// ─── Sleep Tab ────────────────────────────────────────────────────────────────

class _SleepInsights extends ConsumerWidget {
  final int days;
  const _SleepInsights({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepsAsync = ref.watch(sleepEntriesProvider);
    return sleepsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (sleeps) {
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final completed = sleeps.where((s) => s.endTime != null && s.timestamp.isAfter(cutoff)).toList();
        final byDay = _groupByDay(completed, days,
            (s) => s.endTime!.difference(s.startTime).inMinutes / 60.0);
        final avg = byDay.isEmpty ? 0.0 : byDay.values.reduce((a, b) => a + b) / byDay.length;
        final longest = completed.isEmpty ? Duration.zero
            : completed.map((s) => s.endTime!.difference(s.startTime)).reduce((a, b) => a > b ? a : b);
        return _InsightLayout(
          stats: [
            _StatCard('Avg hrs/day', avg.toStringAsFixed(1), icon: Icons.bedtime_outlined),
            _StatCard('Longest stretch', '${longest.inHours}h ${longest.inMinutes % 60}m', icon: Icons.star_outline),
          ],
          chart: _BarChartWidget(data: byDay, color: EntryColors.sleep, unit: 'hrs'),
        );
      },
    );
  }
}

// ─── Diaper Tab ───────────────────────────────────────────────────────────────

class _DiaperInsights extends ConsumerWidget {
  final int days;
  const _DiaperInsights({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diapersAsync = ref.watch(diaperEntriesProvider);
    return diapersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (diapers) {
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final recent = diapers.where((d) => d.timestamp.isAfter(cutoff)).toList();
        final byDay = _groupByDay(recent, days, (_) => 1.0);
        final avg = byDay.isEmpty ? 0.0 : byDay.values.reduce((a, b) => a + b) / byDay.length;
        final wet = recent.where((d) => d.diaperType == 'wet' || d.diaperType == 'both').length;
        return _InsightLayout(
          stats: [
            _StatCard('Avg per day', avg.toStringAsFixed(1), icon: Icons.baby_changing_station_outlined),
            _StatCard('Wet today', '${diapers.where(_isToday).where((d) => d.diaperType != 'dry').length}', icon: Icons.water_drop_outlined),
          ],
          chart: _BarChartWidget(data: byDay, color: EntryColors.diaper, unit: 'count'),
        );
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Map<int, double> _groupByDay<T>(List<T> items, int days, double Function(T) value) {
  final now = DateTime.now();
  final map = <int, double>{};
  for (var i = 0; i < days; i++) map[i] = 0.0;
  for (final item in items) {
    DateTime dt;
    if (item is FeedEntriesData) dt = item.timestamp;
    else if (item is SleepEntriesData) dt = item.timestamp;
    else if (item is DiaperEntriesData) dt = item.timestamp;
    else continue;
    final daysAgo = now.difference(dt).inDays;
    if (daysAgo < days) map[daysAgo] = (map[daysAgo] ?? 0) + value(item);
  }
  return map;
}

bool _isToday<T>(T item) {
  DateTime dt;
  if (item is FeedEntriesData) dt = item.timestamp;
  else if (item is DiaperEntriesData) dt = item.timestamp;
  else return false;
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

class _InsightLayout extends StatelessWidget {
  final List<_StatCard> stats;
  final Widget chart;
  const _InsightLayout({required this.stats, required this.chart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: stats.map((s) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8), child: s))).toList()),
        const SizedBox(height: 16),
        chart,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(this.label, this.value, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _BarChartWidget extends StatelessWidget {
  final Map<int, double> data;
  final Color color;
  final String unit;
  const _BarChartWidget({required this.data, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);
    final bars = data.entries.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [BarChartRodData(
        toY: e.value,
        color: color.withOpacity(e.key == 0 ? 1.0 : 0.6),
        width: data.length <= 7 ? 20 : 8,
        borderRadius: BorderRadius.circular(4),
      )],
    )).toList()..sort((a, b) => b.x.compareTo(a.x));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last ${data.length} days', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.3,
                barGroups: bars,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: data.length <= 7,
                    getTitlesWidget: (v, _) {
                      final days = v.toInt();
                      if (days == 0) return const Text('Today', style: TextStyle(fontSize: 10));
                      return Text('${days}d', style: const TextStyle(fontSize: 10));
                    },
                  )),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
