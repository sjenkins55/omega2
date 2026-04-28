import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/health.dart';
import '../../models/sync_types.dart';
import '../../providers/providers.dart';

// ─── WHO Percentile Data ───────────────────────────────────────────────────────

const _whoMonths = [0, 1, 2, 3, 4, 5, 6, 9, 12, 18, 24];

const _whoWeightBoysP3 = [2.5, 3.4, 4.3, 5.0, 5.6, 6.1, 6.5, 7.5, 8.4, 9.6, 10.8];
const _whoWeightBoysP50 = [3.3, 4.5, 5.6, 6.4, 7.0, 7.5, 7.9, 9.2, 10.2, 11.5, 12.6];
const _whoWeightBoysP97 = [4.3, 5.8, 7.1, 8.0, 8.7, 9.3, 9.8, 11.3, 12.5, 14.1, 15.5];

const _whoWeightGirlsP3 = [2.4, 3.2, 4.0, 4.6, 5.1, 5.5, 5.8, 6.9, 7.7, 8.9, 10.0];
const _whoWeightGirlsP50 = [3.2, 4.2, 5.1, 5.8, 6.4, 6.9, 7.3, 8.5, 9.5, 10.9, 12.1];
const _whoWeightGirlsP97 = [4.2, 5.5, 6.6, 7.5, 8.2, 8.8, 9.3, 10.9, 12.2, 13.9, 15.4];

// ─── Percentile Calculation ────────────────────────────────────────────────────

double _interpolate(List<double> p, double ageMonths) {
  for (int i = 0; i < _whoMonths.length - 1; i++) {
    final m0 = _whoMonths[i].toDouble();
    final m1 = _whoMonths[i + 1].toDouble();
    if (ageMonths >= m0 && ageMonths <= m1) {
      final t = (ageMonths - m0) / (m1 - m0);
      return p[i] + t * (p[i + 1] - p[i]);
    }
  }
  if (ageMonths < _whoMonths.first) return p.first;
  return p.last;
}

double? _weightPercentile(double value, double ageMonths, bool isBoy) {
  final p3 = _interpolate(isBoy ? _whoWeightBoysP3 : _whoWeightGirlsP3, ageMonths);
  final p50 = _interpolate(isBoy ? _whoWeightBoysP50 : _whoWeightGirlsP50, ageMonths);
  final p97 = _interpolate(isBoy ? _whoWeightBoysP97 : _whoWeightGirlsP97, ageMonths);
  if (value <= p3) return 3.0 * (value / p3);
  if (value <= p50) {
    return 3.0 + 47.0 * (value - p3) / (p50 - p3);
  }
  return 50.0 + 47.0 * (value - p50) / (p97 - p50);
}

// ─── Chart Spot Builders ───────────────────────────────────────────────────────

List<FlSpot> _buildWhoSpots(List<double> data) {
  return List.generate(_whoMonths.length, (i) => FlSpot(_whoMonths[i].toDouble(), data[i]));
}

// ─── Growth Screen ─────────────────────────────────────────────────────────────

class GrowthScreen extends ConsumerStatefulWidget {
  final BabiesData baby;
  const GrowthScreen({super.key, required this.baby});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  MeasurementType _selectedType = MeasurementType.weight;

  String get _unit {
    switch (_selectedType) {
      case MeasurementType.weight:
        return 'kg';
      case MeasurementType.height:
      case MeasurementType.headCircumference:
        return 'cm';
    }
  }

  String get _typeLabel {
    switch (_selectedType) {
      case MeasurementType.weight:
        return 'Weight';
      case MeasurementType.height:
        return 'Height';
      case MeasurementType.headCircumference:
        return 'Head Circ';
    }
  }

  double _ageInMonths(DateTime timestamp) {
    final dob = widget.baby.dateOfBirth;
    return (timestamp.year - dob.year) * 12.0 +
        (timestamp.month - dob.month) +
        (timestamp.day - dob.day) / 30.0;
  }

  Future<void> _showAddMeasurementDialog(
      List<MeasurementsData> existing) async {
    DateTime selectedDate = DateTime.now();
    final valueController = TextEditingController();
    MeasurementType type = _selectedType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Add Measurement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type selector
                SegmentedButton<MeasurementType>(
                  segments: const [
                    ButtonSegment(
                        value: MeasurementType.weight, label: Text('Weight')),
                    ButtonSegment(
                        value: MeasurementType.height, label: Text('Height')),
                    ButtonSegment(
                        value: MeasurementType.headCircumference,
                        label: Text('Head')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setS(() => type = s.first),
                ),
                const SizedBox(height: 16),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: widget.baby.dateOfBirth,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => selectedDate = d);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: type == MeasurementType.weight
                        ? 'Weight (kg)'
                        : 'Length (cm)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      }),
    );

    if (confirmed != true) return;

    final raw = double.tryParse(valueController.text.trim());
    if (raw == null) return;

    final caregiver = await ref.read(currentCaregiverProvider.future);
    final caregiverId = caregiver?.id ?? 'local';
    final db = ref.read(databaseProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();

    final companion = MeasurementsCompanion(
      id: Value(id),
      babyId: Value(widget.baby.id),
      caregiverId: Value(caregiverId),
      timestamp: Value(selectedDate),
      type: Value(type.name),
      value: Value(raw),
      unit: Value(type == MeasurementType.weight
          ? MeasurementUnit.kg.name
          : MeasurementUnit.cm.name),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await db.upsertMeasurement(companion);

    ref.read(syncManagerProvider.notifier).enqueue(SyncOperation(
          modelType: 'measurement',
          modelId: id,
          operation: SyncOperationType.insert,
          payload: {
            'id': id,
            'babyId': widget.baby.id,
            'caregiverId': caregiverId,
            'timestamp': selectedDate.toIso8601String(),
            'type': type.name,
            'value': raw,
            'unit': type == MeasurementType.weight
                ? MeasurementUnit.kg.name
                : MeasurementUnit.cm.name,
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final measurementsStream = db.select(db.measurements)
      ..where((m) => m.babyId.equals(widget.baby.id))
      ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]);

    return Scaffold(
      appBar: AppBar(title: const Text('Growth')),
      body: StreamBuilder<List<MeasurementsData>>(
        stream: measurementsStream.watch(),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final filtered = all
              .where((m) => m.type == _selectedType.name)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type chips
                      Wrap(
                        spacing: 8,
                        children: MeasurementType.values.map((t) {
                          return ChoiceChip(
                            label: Text(_typeLabelFor(t)),
                            selected: _selectedType == t,
                            onSelected: (_) =>
                                setState(() => _selectedType = t),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Chart
                      _GrowthChart(
                        measurements: filtered,
                        baby: widget.baby,
                        type: _selectedType,
                      ),
                      const SizedBox(height: 12),
                      // Percentile card
                      if (filtered.isNotEmpty && _selectedType == MeasurementType.weight)
                        _PercentileCard(
                          measurement: filtered.last,
                          baby: widget.baby,
                          ageMonths: _ageInMonths(filtered.last.timestamp),
                        ),
                    ],
                  ),
                ),
              ),
              // Measurement list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final m = filtered[filtered.length - 1 - i];
                    final ageM = _ageInMonths(m.timestamp);
                    double? pct;
                    if (_selectedType == MeasurementType.weight) {
                      pct = _weightPercentile(
                          m.value, ageM, widget.baby.gender == 'male');
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF00BCD4).withOpacity(0.15),
                          child: const Icon(Icons.straighten, color: Color(0xFF00BCD4)),
                        ),
                        title: Text(
                          '${m.value.toStringAsFixed(m.value < 10 ? 2 : 1)} ${m.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(DateFormat.yMMMd().format(m.timestamp)),
                        trailing: pct != null
                            ? _percentileBadge(pct)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMeasurementDialog([]),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _typeLabelFor(MeasurementType t) {
    switch (t) {
      case MeasurementType.weight:
        return 'Weight';
      case MeasurementType.height:
        return 'Height';
      case MeasurementType.headCircumference:
        return 'Head Circ';
    }
  }

  Widget _percentileBadge(double pct) {
    Color color;
    if (pct < 10 || pct > 90) {
      color = Colors.orange;
    } else if (pct < 3 || pct > 97) {
      color = Colors.red;
    } else {
      color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}th',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

// ─── Growth Chart ──────────────────────────────────────────────────────────────

class _GrowthChart extends StatelessWidget {
  final List<MeasurementsData> measurements;
  final BabiesData baby;
  final MeasurementType type;

  const _GrowthChart({
    required this.measurements,
    required this.baby,
    required this.type,
  });

  double _ageInMonths(DateTime timestamp) {
    final dob = baby.dateOfBirth;
    return (timestamp.year - dob.year) * 12.0 +
        (timestamp.month - dob.month) +
        (timestamp.day - dob.day) / 30.0;
  }

  @override
  Widget build(BuildContext context) {
    final isBoy = baby.gender == 'male';
    final showWho = type == MeasurementType.weight;

    final List<FlSpot> p3Spots = showWho
        ? _buildWhoSpots(isBoy ? _whoWeightBoysP3 : _whoWeightGirlsP3)
        : [];
    final List<FlSpot> p50Spots = showWho
        ? _buildWhoSpots(isBoy ? _whoWeightBoysP50 : _whoWeightGirlsP50)
        : [];
    final List<FlSpot> p97Spots = showWho
        ? _buildWhoSpots(isBoy ? _whoWeightBoysP97 : _whoWeightGirlsP97)
        : [];

    final babySpots = measurements.map((m) {
      return FlSpot(_ageInMonths(m.timestamp), m.value);
    }).toList();

    // Calculate y-axis range
    double minY = 0;
    double maxY = showWho ? 16 : 100;
    if (babySpots.isNotEmpty) {
      final allY = [
        ...babySpots.map((s) => s.y),
        if (showWho) ...p3Spots.map((s) => s.y),
        if (showWho) ...p97Spots.map((s) => s.y),
      ];
      minY = math.max(0, allY.reduce(math.min) - 1);
      maxY = allY.reduce(math.max) + 1;
    }

    final lineBarsData = <LineChartBarData>[
      if (showWho) ...[
        LineChartBarData(
          spots: p97Spots,
          isCurved: true,
          color: Colors.grey.shade400,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: [6, 4],
        ),
        LineChartBarData(
          spots: p50Spots,
          isCurved: true,
          color: Colors.green.shade400,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: [6, 4],
        ),
        LineChartBarData(
          spots: p3Spots,
          isCurved: true,
          color: Colors.grey.shade400,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: [6, 4],
        ),
      ],
      if (babySpots.isNotEmpty)
        LineChartBarData(
          spots: babySpots,
          isCurved: false,
          color: Colors.blue.shade600,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: Colors.blue.shade600,
              strokeColor: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
    ];

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 24,
          minY: minY,
          maxY: maxY,
          lineBarsData: lineBarsData,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => Text(
                  v.toStringAsFixed(type == MeasurementType.weight ? 0 : 0),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 3,
                getTitlesWidget: (v, meta) => Text(
                  '${v.toInt()}m',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ─── Percentile Card ───────────────────────────────────────────────────────────

class _PercentileCard extends StatelessWidget {
  final MeasurementsData measurement;
  final BabiesData baby;
  final double ageMonths;

  const _PercentileCard({
    required this.measurement,
    required this.baby,
    required this.ageMonths,
  });

  @override
  Widget build(BuildContext context) {
    final pct = _weightPercentile(
        measurement.value, ageMonths, baby.gender == 'male');
    if (pct == null) return const SizedBox.shrink();

    Color color;
    String message;
    if (pct < 3) {
      color = Colors.red;
      message = 'Below 3rd percentile – consult your pediatrician';
    } else if (pct < 10) {
      color = Colors.orange;
      message = 'Below average – monitor closely';
    } else if (pct > 97) {
      color = Colors.red;
      message = 'Above 97th percentile – consult your pediatrician';
    } else if (pct > 90) {
      color = Colors.orange;
      message = 'Above average';
    } else {
      color = Colors.green;
      message = 'Healthy growth range';
    }

    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.show_chart, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${baby.name} is at the ${pct.toStringAsFixed(0)}th percentile',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: color, fontSize: 15),
                  ),
                  Text(message, style: TextStyle(color: color, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
