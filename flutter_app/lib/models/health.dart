import 'sync_types.dart';

// ─── Measurement ──────────────────────────────────────────────────────────────

enum MeasurementType { weight, height, headCircumference }
enum MeasurementUnit { kg, lbs, cm, inches }

class Measurement {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  MeasurementType type;
  double value;
  MeasurementUnit unit;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Measurement({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.timestamp,
    required this.type,
    required this.value,
    required this.unit,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'value': value,
        'unit': unit.name,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        type: MeasurementType.values.byName(j['type'] as String),
        value: (j['value'] as num).toDouble(),
        unit: MeasurementUnit.values.byName(j['unit'] as String),
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Milestone ────────────────────────────────────────────────────────────────

class MilestoneEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  String? milestoneKey;
  String? customTitle;
  DateTime achievedAt;
  List<int>? photoBytes;   // stored locally; URL used when synced
  String? photoUrl;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  MilestoneEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.achievedAt,
    this.milestoneKey,
    this.customTitle,
    this.photoBytes,
    this.photoUrl,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : timestamp = achievedAt,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayTitle => customTitle ?? milestoneKey ?? 'Milestone';

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'milestoneKey': milestoneKey,
        'customTitle': customTitle,
        'photoUrl': photoUrl,
        'notes': notes,
        'achievedAt': achievedAt.toIso8601String(),
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MilestoneEntry.fromJson(Map<String, dynamic> j) => MilestoneEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        achievedAt: DateTime.parse(j['achievedAt'] as String),
        milestoneKey: j['milestoneKey'] as String?,
        customTitle: j['customTitle'] as String?,
        photoUrl: j['photoUrl'] as String?,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Vaccine ──────────────────────────────────────────────────────────────────

class VaccineEntry {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  String? vaccineKey;
  String? customName;
  DateTime administeredAt;
  String? lotNumber;
  String? provider;
  String? reactions;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  VaccineEntry({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.administeredAt,
    this.vaccineKey,
    this.customName,
    this.lotNumber,
    this.provider,
    this.reactions,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : timestamp = administeredAt,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName => customName ?? vaccineKey ?? 'Vaccine';

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'vaccineKey': vaccineKey,
        'customName': customName,
        'administeredAt': administeredAt.toIso8601String(),
        'lotNumber': lotNumber,
        'provider': provider,
        'reactions': reactions,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaccineEntry.fromJson(Map<String, dynamic> j) => VaccineEntry(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        administeredAt: DateTime.parse(j['administeredAt'] as String),
        vaccineKey: j['vaccineKey'] as String?,
        customName: j['customName'] as String?,
        lotNumber: j['lotNumber'] as String?,
        provider: j['provider'] as String?,
        reactions: j['reactions'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Appointment ──────────────────────────────────────────────────────────────

enum AppointmentType { wellVisit, sick, specialist, other }

class Appointment {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime timestamp;
  DateTime scheduledAt;
  AppointmentType appointmentType;
  String? provider;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Appointment({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.scheduledAt,
    this.appointmentType = AppointmentType.wellVisit,
    this.provider,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : timestamp = scheduledAt,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'timestamp': timestamp.toIso8601String(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'appointmentType': appointmentType.name,
        'provider': provider,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        scheduledAt: DateTime.parse(j['scheduledAt'] as String),
        appointmentType:
            AppointmentType.values.byName(j['appointmentType'] as String? ?? 'wellVisit'),
        provider: j['provider'] as String?,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

// ─── Medication ───────────────────────────────────────────────────────────────

enum DoseUnit { mg, ml, drops, puffs, tsp }
enum MedRoute { oral, topical, inhaled, nasal, other }

class Medication {
  final String id;
  final String babyId;
  final String createdById;
  String name;
  double dose;
  DoseUnit doseUnit;
  MedRoute route;
  bool isScheduled;
  double? frequencyHours;
  DateTime startDate;
  DateTime? endDate;
  bool isActive;
  String? prescribedBy;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Medication({
    required this.id,
    required this.babyId,
    required this.createdById,
    required this.name,
    required this.dose,
    required this.doseUnit,
    required this.route,
    this.isScheduled = false,
    this.frequencyHours,
    DateTime? startDate,
    this.endDate,
    this.isActive = true,
    this.prescribedBy,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'createdById': createdById,
        'name': name,
        'dose': dose,
        'doseUnit': doseUnit.name,
        'route': route.name,
        'isScheduled': isScheduled,
        'frequencyHours': frequencyHours,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isActive': isActive,
        'prescribedBy': prescribedBy,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        createdById: j['createdById'] as String,
        name: j['name'] as String,
        dose: (j['dose'] as num).toDouble(),
        doseUnit: DoseUnit.values.byName(j['doseUnit'] as String),
        route: MedRoute.values.byName(j['route'] as String),
        isScheduled: j['isScheduled'] as bool? ?? false,
        frequencyHours: (j['frequencyHours'] as num?)?.toDouble(),
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : null,
        isActive: j['isActive'] as bool? ?? true,
        prescribedBy: j['prescribedBy'] as String?,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class MedicationDose {
  final String id;
  final String medicationId;
  final String caregiverId;
  DateTime administeredAt;
  bool skipped;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;

  MedicationDose({
    required this.id,
    required this.medicationId,
    required this.caregiverId,
    DateTime? administeredAt,
    this.skipped = false,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
  })  : administeredAt = administeredAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'caregiverId': caregiverId,
        'administeredAt': administeredAt.toIso8601String(),
        'skipped': skipped,
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MedicationDose.fromJson(Map<String, dynamic> j) => MedicationDose(
        id: j['id'] as String,
        medicationId: j['medicationId'] as String,
        caregiverId: j['caregiverId'] as String,
        administeredAt: DateTime.parse(j['administeredAt'] as String),
        skipped: j['skipped'] as bool? ?? false,
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ─── Illness ──────────────────────────────────────────────────────────────────

enum Symptom {
  fever, cough, runnyNose, congestion, vomiting, diarrhea,
  rash, earPain, eyeDischarge, reducedAppetite, fussiness, lethargy, other;

  String get label {
    switch (this) {
      case Symptom.fever:           return 'Fever';
      case Symptom.cough:           return 'Cough';
      case Symptom.runnyNose:       return 'Runny Nose';
      case Symptom.congestion:      return 'Congestion';
      case Symptom.vomiting:        return 'Vomiting';
      case Symptom.diarrhea:        return 'Diarrhea';
      case Symptom.rash:            return 'Rash';
      case Symptom.earPain:         return 'Ear Pain';
      case Symptom.eyeDischarge:    return 'Eye Discharge';
      case Symptom.reducedAppetite: return 'Reduced Appetite';
      case Symptom.fussiness:       return 'Fussiness';
      case Symptom.lethargy:        return 'Lethargy';
      case Symptom.other:           return 'Other';
    }
  }
}

class Illness {
  final String id;
  final String babyId;
  final String caregiverId;
  DateTime onsetDate;
  DateTime? endDate;
  List<Symptom> symptoms;
  String? notes;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Illness({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.onsetDate,
    this.endDate,
    this.symptoms = const [],
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => endDate == null;

  int get daysActive =>
      (endDate ?? DateTime.now()).difference(onsetDate).inDays + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'onsetDate': onsetDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'symptoms': symptoms.map((s) => s.name).toList(),
        'notes': notes,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Illness.fromJson(Map<String, dynamic> j) => Illness(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        onsetDate: DateTime.parse(j['onsetDate'] as String),
        endDate: j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : null,
        symptoms: (j['symptoms'] as List<dynamic>?)
                ?.map((s) => Symptom.values.byName(s as String))
                .toList() ??
            [],
        notes: j['notes'] as String?,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
