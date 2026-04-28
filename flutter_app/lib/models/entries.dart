import 'sync_types.dart';

// ─── Feed ─────────────────────────────────────────────────────────────────────

enum FeedType { breast, bottle, solids, pump }
enum BreastSide { left, right, both }
enum FormulaType { standard, sensitive, soy, hypoallergenic, other }

class FeedEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  FeedType feedType;
  // Breast
  BreastSide? side;
  int? leftDurationSeconds;
  int? rightDurationSeconds;
  // Bottle
  double? amountMl;
  bool? isBreastMilk;
  FormulaType? formulaType;
  // Solids
  String? foodDescription;
  // Pump
  double? pumpedMl;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  FeedEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.feedType,
    this.side,
    this.leftDurationSeconds,
    this.rightDurationSeconds,
    this.amountMl,
    this.isBreastMilk,
    this.formulaType,
    this.foodDescription,
    this.pumpedMl,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalDurationSeconds =>
      (leftDurationSeconds ?? 0) + (rightDurationSeconds ?? 0);

  String get primaryLabel {
    switch (feedType) {
      case FeedType.breast:
        final mins = totalDurationSeconds ~/ 60;
        return '$mins min nursing';
      case FeedType.bottle:
        return amountMl != null ? '${amountMl!.toStringAsFixed(0)} ml' : 'Bottle';
      case FeedType.solids:
        return foodDescription ?? 'Solids';
      case FeedType.pump:
        return pumpedMl != null ? '${pumpedMl!.toStringAsFixed(0)} ml pumped' : 'Pump';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'feedType': feedType.name,
        'side': side?.name,
        'leftDurationSeconds': leftDurationSeconds,
        'rightDurationSeconds': rightDurationSeconds,
        'amountMl': amountMl,
        'isBreastMilk': isBreastMilk,
        'formulaType': formulaType?.name,
        'foodDescription': foodDescription,
        'pumpedMl': pumpedMl,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FeedEntry.fromJson(Map<String, dynamic> j) => FeedEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        feedType: FeedType.values.byName(j['feedType'] as String),
        side: j['side'] != null ? BreastSide.values.byName(j['side'] as String) : null,
        leftDurationSeconds: j['leftDurationSeconds'] as int?,
        rightDurationSeconds: j['rightDurationSeconds'] as int?,
        amountMl: (j['amountMl'] as num?)?.toDouble(),
        isBreastMilk: j['isBreastMilk'] as bool?,
        formulaType: j['formulaType'] != null
            ? FormulaType.values.byName(j['formulaType'] as String)
            : null,
        foodDescription: j['foodDescription'] as String?,
        pumpedMl: (j['pumpedMl'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Sleep ────────────────────────────────────────────────────────────────────

class SleepEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  DateTime startTime;
  DateTime? endTime;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  SleepEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.startTime,
    this.endTime,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isOngoing => endTime == null;

  Duration get duration => isOngoing
      ? DateTime.now().difference(startTime)
      : endTime!.difference(startTime);

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SleepEntry.fromJson(Map<String, dynamic> j) => SleepEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null ? DateTime.parse(j['endTime'] as String) : null,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Diaper ───────────────────────────────────────────────────────────────────

enum DiaperType { wet, dirty, both, dry }
enum StoolColor { yellow, green, brown, orange, red, black, white, other }

class DiaperEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  DiaperType diaperType;
  StoolColor? stoolColor;
  bool hasRash;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  DiaperEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.diaperType,
    this.stoolColor,
    this.hasRash = false,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get requiresAttention =>
      stoolColor == StoolColor.red ||
      stoolColor == StoolColor.black ||
      stoolColor == StoolColor.white;

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'diaperType': diaperType.name,
        'stoolColor': stoolColor?.name,
        'hasRash': hasRash,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DiaperEntry.fromJson(Map<String, dynamic> j) => DiaperEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        diaperType: DiaperType.values.byName(j['diaperType'] as String),
        stoolColor: j['stoolColor'] != null
            ? StoolColor.values.byName(j['stoolColor'] as String)
            : null,
        hasRash: j['hasRash'] as bool? ?? false,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Temperature ──────────────────────────────────────────────────────────────

enum TempUnit { fahrenheit, celsius }
enum TempMethod { rectal, axillary, oral, temporal, tympanic }

class TemperatureEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  double valueFahrenheit;
  TempMethod method;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  TemperatureEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.valueFahrenheit,
    this.method = TempMethod.axillary,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isFever => valueFahrenheit >= 100.4;

  double get valueCelsius => (valueFahrenheit - 32) * 5 / 9;

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'valueFahrenheit': valueFahrenheit,
        'method': method.name,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TemperatureEntry.fromJson(Map<String, dynamic> j) => TemperatureEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        valueFahrenheit: (j['valueFahrenheit'] as num).toDouble(),
        method: TempMethod.values.byName(j['method'] as String? ?? 'axillary'),
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
