import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Babies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get dateOfBirth => dateTime()();
  TextColumn get gender => text()();
  BoolColumn get isPreterm => boolean().withDefault(const Constant(false))();
  IntColumn get weeksGestation => integer().nullable()();
  TextColumn get photoUrl => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeedEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get feedType => text()();
  TextColumn get side => text().nullable()();
  IntColumn get leftDurationSeconds => integer().nullable()();
  IntColumn get rightDurationSeconds => integer().nullable()();
  RealColumn get amountMl => real().nullable()();
  BoolColumn get isBreastMilk => boolean().nullable()();
  TextColumn get formulaType => text().nullable()();
  TextColumn get foodDescription => text().nullable()();
  RealColumn get pumpedMl => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SleepEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DiaperEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get diaperType => text()();
  TextColumn get stoolColor => text().nullable()();
  BoolColumn get hasRash => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TemperatureEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get valueFahrenheit => real()();
  TextColumn get method => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Measurements extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MilestoneEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get milestoneKey => text().nullable()();
  TextColumn get customTitle => text().nullable()();
  DateTimeColumn get achievedAt => dateTime()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VaccineEntries extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get vaccineKey => text().nullable()();
  TextColumn get customName => text().nullable()();
  DateTimeColumn get administeredAt => dateTime()();
  TextColumn get lotNumber => text().nullable()();
  TextColumn get provider => text().nullable()();
  TextColumn get reactions => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Appointments extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get appointmentType => text()();
  TextColumn get provider => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Medications extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get createdById => text()();
  TextColumn get name => text()();
  RealColumn get dose => real()();
  TextColumn get doseUnit => text()();
  TextColumn get route => text()();
  BoolColumn get isScheduled => boolean()();
  RealColumn get frequencyHours => real().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get prescribedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MedicationDoses extends Table {
  TextColumn get id => text()();
  TextColumn get medicationId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get administeredAt => dateTime()();
  BoolColumn get skipped => boolean()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Illnesses extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  DateTimeColumn get onsetDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  // Comma-separated symptom enum names
  TextColumn get symptomsJson => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Caregivers extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get supabaseUserId => text().nullable()();
  TextColumn get role => text()();
  BoolColumn get isCurrentDevice => boolean()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Named BabyAccessTable to avoid conflict with the BabyAccess model class
@DataClassName('BabyAccessData')
class BabyAccessTable extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  TextColumn get role => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'baby_access';
}

class HandoffNotes extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get caregiverId => text()();
  TextColumn get body => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CaregiverInvites extends Table {
  TextColumn get id => text()();
  TextColumn get babyId => text()();
  TextColumn get createdById => text()();
  TextColumn get code => text()();
  TextColumn get grantedRole => text()();
  DateTimeColumn get expiresAt => dateTime()();
  BoolColumn get isRedeemed => boolean()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Babies,
  FeedEntries,
  SleepEntries,
  DiaperEntries,
  TemperatureEntries,
  Measurements,
  MilestoneEntries,
  VaccineEntries,
  Appointments,
  Medications,
  MedicationDoses,
  Illnesses,
  Caregivers,
  BabyAccessTable,
  HandoffNotes,
  CaregiverInvites,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'baby_tracker');
  }
}

// ─── DAO Extension Methods ────────────────────────────────────────────────────

extension AppDatabaseDao on AppDatabase {
  // ── Watch streams ─────────────────────────────────────────────────────────

  Stream<List<BabiesData>> watchBabies() {
    return (select(babies)
          ..where((b) => b.isArchived.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .watch();
  }

  Stream<List<FeedEntriesData>> watchFeedEntries(String babyId) {
    return (select(feedEntries)
          ..where((f) => f.babyId.equals(babyId))
          ..orderBy([(f) => OrderingTerm.desc(f.timestamp)]))
        .watch();
  }

  Stream<List<SleepEntriesData>> watchSleepEntries(String babyId) {
    return (select(sleepEntries)
          ..where((s) => s.babyId.equals(babyId))
          ..orderBy([(s) => OrderingTerm.desc(s.timestamp)]))
        .watch();
  }

  Stream<List<DiaperEntriesData>> watchDiaperEntries(String babyId) {
    return (select(diaperEntries)
          ..where((d) => d.babyId.equals(babyId))
          ..orderBy([(d) => OrderingTerm.desc(d.timestamp)]))
        .watch();
  }

  Stream<List<MedicationsData>> watchMedications(String babyId) {
    return (select(medications)
          ..where((m) => m.babyId.equals(babyId))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .watch();
  }

  Stream<List<IllnessesData>> watchIllnesses(String babyId) {
    return (select(illnesses)
          ..where((i) => i.babyId.equals(babyId))
          ..orderBy([(i) => OrderingTerm.desc(i.onsetDate)]))
        .watch();
  }

  Stream<List<AppointmentsData>> watchAppointments(String babyId) {
    return (select(appointments)
          ..where((a) => a.babyId.equals(babyId))
          ..orderBy([(a) => OrderingTerm.asc(a.scheduledAt)]))
        .watch();
  }

  Stream<CaregiversData?> watchCurrentCaregiver() {
    return (select(caregivers)
          ..where((c) => c.isCurrentDevice.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  // ── Today helpers ─────────────────────────────────────────────────────────

  Future<List<FeedEntriesData>> getTodayFeedEntries(String babyId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(feedEntries)
          ..where((f) =>
              f.babyId.equals(babyId) &
              f.timestamp.isBiggerOrEqualValue(startOfDay) &
              f.timestamp.isSmallerThanValue(endOfDay))
          ..orderBy([(f) => OrderingTerm.desc(f.timestamp)]))
        .get();
  }

  Future<List<SleepEntriesData>> getTodaySleepEntries(String babyId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(sleepEntries)
          ..where((s) =>
              s.babyId.equals(babyId) &
              s.timestamp.isBiggerOrEqualValue(startOfDay) &
              s.timestamp.isSmallerThanValue(endOfDay))
          ..orderBy([(s) => OrderingTerm.desc(s.timestamp)]))
        .get();
  }

  Future<List<DiaperEntriesData>> getTodayDiaperEntries(String babyId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(diaperEntries)
          ..where((d) =>
              d.babyId.equals(babyId) &
              d.timestamp.isBiggerOrEqualValue(startOfDay) &
              d.timestamp.isSmallerThanValue(endOfDay))
          ..orderBy([(d) => OrderingTerm.desc(d.timestamp)]))
        .get();
  }

  // ── Last entry lookups ────────────────────────────────────────────────────

  Future<FeedEntriesData?> getLastFeedEntry(String babyId) {
    return (select(feedEntries)
          ..where((f) => f.babyId.equals(babyId))
          ..orderBy([(f) => OrderingTerm.desc(f.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<SleepEntriesData?> getLastSleepEntry(String babyId) {
    return (select(sleepEntries)
          ..where((s) => s.babyId.equals(babyId))
          ..orderBy([(s) => OrderingTerm.desc(s.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<SleepEntriesData?> getActiveSleep(String babyId) {
    return (select(sleepEntries)
          ..where((s) => s.babyId.equals(babyId) & s.endTime.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CaregiversData?> getCurrentCaregiver() {
    return (select(caregivers)
          ..where((c) => c.isCurrentDevice.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  // ── Upserts ───────────────────────────────────────────────────────────────

  Future<void> upsertBaby(BabiesCompanion companion) async {
    await into(babies).insertOnConflictUpdate(companion);
  }

  Future<void> upsertFeedEntry(FeedEntriesCompanion companion) async {
    await into(feedEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertSleepEntry(SleepEntriesCompanion companion) async {
    await into(sleepEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertDiaperEntry(DiaperEntriesCompanion companion) async {
    await into(diaperEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertTemperatureEntry(TemperatureEntriesCompanion companion) async {
    await into(temperatureEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertMeasurement(MeasurementsCompanion companion) async {
    await into(measurements).insertOnConflictUpdate(companion);
  }

  Future<void> upsertMilestoneEntry(MilestoneEntriesCompanion companion) async {
    await into(milestoneEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertVaccineEntry(VaccineEntriesCompanion companion) async {
    await into(vaccineEntries).insertOnConflictUpdate(companion);
  }

  Future<void> upsertAppointment(AppointmentsCompanion companion) async {
    await into(appointments).insertOnConflictUpdate(companion);
  }

  Future<void> upsertMedication(MedicationsCompanion companion) async {
    await into(medications).insertOnConflictUpdate(companion);
  }

  Future<void> upsertMedicationDose(MedicationDosesCompanion companion) async {
    await into(medicationDoses).insertOnConflictUpdate(companion);
  }

  Future<void> upsertIllness(IllnessesCompanion companion) async {
    await into(illnesses).insertOnConflictUpdate(companion);
  }

  Future<void> upsertCaregiver(CaregiversCompanion companion) async {
    await into(caregivers).insertOnConflictUpdate(companion);
  }

  Future<void> upsertHandoffNote(HandoffNotesCompanion companion) async {
    await into(handoffNotes).insertOnConflictUpdate(companion);
  }

  Future<void> upsertCaregiverInvite(CaregiverInvitesCompanion companion) async {
    await into(caregiverInvites).insertOnConflictUpdate(companion);
  }

  // ── Deletes ───────────────────────────────────────────────────────────────

  Future<void> deleteFeedEntry(String id) async {
    await (delete(feedEntries)..where((f) => f.id.equals(id))).go();
  }

  Future<void> deleteSleepEntry(String id) async {
    await (delete(sleepEntries)..where((s) => s.id.equals(id))).go();
  }

  Future<void> deleteDiaperEntry(String id) async {
    await (delete(diaperEntries)..where((d) => d.id.equals(id))).go();
  }

  Future<void> deleteTemperatureEntry(String id) async {
    await (delete(temperatureEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteMeasurement(String id) async {
    await (delete(measurements)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteMilestoneEntry(String id) async {
    await (delete(milestoneEntries)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteVaccineEntry(String id) async {
    await (delete(vaccineEntries)..where((v) => v.id.equals(id))).go();
  }

  Future<void> deleteAppointment(String id) async {
    await (delete(appointments)..where((a) => a.id.equals(id))).go();
  }

  Future<void> deleteMedication(String id) async {
    await (delete(medications)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteMedicationDose(String id) async {
    await (delete(medicationDoses)..where((d) => d.id.equals(id))).go();
  }

  Future<void> deleteIllness(String id) async {
    await (delete(illnesses)..where((i) => i.id.equals(id))).go();
  }

  Future<void> deleteBaby(String id) async {
    await (delete(babies)..where((b) => b.id.equals(id))).go();
  }
}
