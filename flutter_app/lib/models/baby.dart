import 'sync_types.dart';

enum BabyGender { male, female, other }

class Baby {
  final String id;
  String name;
  DateTime dateOfBirth;
  BabyGender gender;
  bool isPreterm;
  int? weeksGestation;   // for corrected age calc
  String? photoUrl;
  bool isArchived;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Baby({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.gender = BabyGender.other,
    this.isPreterm = false,
    this.weeksGestation,
    this.photoUrl,
    this.isArchived = false,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get ageInDays =>
      DateTime.now().difference(dateOfBirth).inDays;

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - dateOfBirth.year) * 12 +
        now.month - dateOfBirth.month;
  }

  // Corrected age for preterm babies
  DateTime get correctedDateOfBirth {
    if (!isPreterm || weeksGestation == null) return dateOfBirth;
    final weeksEarly = 40 - weeksGestation!;
    return dateOfBirth.add(Duration(days: weeksEarly * 7));
  }

  String get ageLabel {
    final months = ageInMonths;
    if (months < 1) return '${ageInDays}d old';
    if (months < 24) return '${months}mo old';
    return '${months ~/ 12}y old';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender.name,
        'isPreterm': isPreterm,
        'weeksGestation': weeksGestation,
        'photoUrl': photoUrl,
        'isArchived': isArchived,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Baby.fromJson(Map<String, dynamic> j) => Baby(
        id: j['id'] as String,
        name: j['name'] as String,
        dateOfBirth: DateTime.parse(j['dateOfBirth'] as String),
        gender: BabyGender.values.byName(j['gender'] as String? ?? 'other'),
        isPreterm: j['isPreterm'] as bool? ?? false,
        weeksGestation: j['weeksGestation'] as int?,
        photoUrl: j['photoUrl'] as String?,
        isArchived: j['isArchived'] as bool? ?? false,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
