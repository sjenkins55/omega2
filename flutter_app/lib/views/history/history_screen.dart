import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../database/app_database.dart';
import '../../providers/providers.dart';

enum _HistoryFilter { all, feed, sleep, diaper }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final feeds   = ref.watch(feedEntriesProvider).valueOrNull ?? [];
    final sleeps  = ref.watch(sleepEntriesProvider).valueOrNull ?? [];
    final diapers = ref.watch(diaperEntriesProvider).valueOrNull ?? [];

    final entries = _buildEntries(feeds, sleeps, diapers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SearchBar(
                  hintText: 'Search entries…',
                  leading: const Icon(Icons.search),
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: _HistoryFilter.values.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.name[0].toUpperCase() + f.name.substring(1)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No entries yet.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final item = entries[i];
                if (item is _DateHeader) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(item.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  );
                }
                return _EntryTile(entry: item as _EntryItem);
              },
            ),
    );
  }

  List<Object> _buildEntries(
    List<FeedEntriesData> feeds,
    List<SleepEntriesData> sleeps,
    List<DiaperEntriesData> diapers,
  ) {
    final items = <_EntryItem>[];

    if (_filter == _HistoryFilter.all || _filter == _HistoryFilter.feed) {
      for (final f in feeds) {
        final label = _feedLabel(f);
        if (_search.isEmpty || label.toLowerCase().contains(_search) || 'feed'.contains(_search)) {
          items.add(_EntryItem(timestamp: f.timestamp, type: _HistoryFilter.feed,
              icon: Icons.local_dining, color: EntryColors.feed,
              primary: label, secondary: _timeAgo(f.timestamp)));
        }
      }
    }
    if (_filter == _HistoryFilter.all || _filter == _HistoryFilter.sleep) {
      for (final s in sleeps) {
        final dur = s.endTime != null ? s.endTime!.difference(s.startTime) : Duration.zero;
        final label = s.endTime == null ? 'Sleeping (ongoing)' : '${dur.inHours}h ${dur.inMinutes % 60}m sleep';
        if (_search.isEmpty || label.toLowerCase().contains(_search) || 'sleep'.contains(_search)) {
          items.add(_EntryItem(timestamp: s.timestamp, type: _HistoryFilter.sleep,
              icon: Icons.bedtime_outlined, color: EntryColors.sleep,
              primary: label, secondary: _timeAgo(s.timestamp)));
        }
      }
    }
    if (_filter == _HistoryFilter.all || _filter == _HistoryFilter.diaper) {
      for (final d in diapers) {
        final label = '${d.diaperType[0].toUpperCase()}${d.diaperType.substring(1)} diaper${d.stoolColor != null ? ' · ${d.stoolColor}' : ''}';
        if (_search.isEmpty || label.toLowerCase().contains(_search) || 'diaper'.contains(_search)) {
          items.add(_EntryItem(timestamp: d.timestamp, type: _HistoryFilter.diaper,
              icon: Icons.baby_changing_station_outlined, color: EntryColors.diaper,
              primary: label, secondary: _timeAgo(d.timestamp)));
        }
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group by date
    final result = <Object>[];
    String? lastDate;
    for (final item in items) {
      final dateLabel = _dateLabel(item.timestamp);
      if (dateLabel != lastDate) {
        result.add(_DateHeader(dateLabel));
        lastDate = dateLabel;
      }
      result.add(item);
    }
    return result;
  }

  String _feedLabel(FeedEntriesData f) {
    switch (f.feedType) {
      case 'breast':
        final total = (f.leftDurationSeconds ?? 0) + (f.rightDurationSeconds ?? 0);
        return '${total ~/ 60}m nursing';
      case 'bottle': return '${f.amountMl?.toStringAsFixed(0) ?? '?'} ml bottle';
      case 'solids': return f.foodDescription ?? 'Solids';
      case 'pump':   return '${f.pumpedMl?.toStringAsFixed(0) ?? '?'} ml pumped';
      default:       return 'Feed';
    }
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat.yMMMd().format(dt);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return DateFormat.jm().format(dt);
  }
}

class _DateHeader { final String label; _DateHeader(this.label); }

class _EntryItem {
  final DateTime timestamp;
  final _HistoryFilter type;
  final IconData icon;
  final Color color;
  final String primary;
  final String secondary;
  const _EntryItem({required this.timestamp, required this.type, required this.icon,
      required this.color, required this.primary, required this.secondary});
}

class _EntryTile extends StatelessWidget {
  final _EntryItem entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.color.withOpacity(0.12),
          child: Icon(entry.icon, color: entry.color, size: 20),
        ),
        title: Text(entry.primary),
        subtitle: Text(entry.secondary),
        dense: true,
      ),
    );
  }
}
