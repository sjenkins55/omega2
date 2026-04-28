import 'sync_types.dart';

enum CaregiverRole { admin, caregiver, viewer }

extension CaregiverRoleX on CaregiverRole {
  String get displayName {
    switch (this) {
      case CaregiverRole.admin:     return 'Admin';
      case CaregiverRole.caregiver: return 'Caregiver';
      case CaregiverRole.viewer:    return 'Viewer';
    }
  }

  bool get canEdit => this != CaregiverRole.viewer;
  bool get canDelete => this == CaregiverRole.admin;
  bool get canManageCaregivers => this == CaregiverRole.admin;
}

class Caregiver {
  final String id;
  String displayName;
  String? email;
  String? supabaseUserId;
  CaregiverRole role;
  bool isCurrentDevice;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  Caregiver({
    required this.id,
    required this.displayName,
    this.email,
    this.supabaseUserId,
    this.role = CaregiverRole.admin,
    this.isCurrentDevice = false,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'supabaseUserId': supabaseUserId,
        'role': role.name,
        'isCurrentDevice': isCurrentDevice,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Caregiver.fromJson(Map<String, dynamic> j) => Caregiver(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        email: j['email'] as String?,
        supabaseUserId: j['supabaseUserId'] as String?,
        role: CaregiverRole.values.byName(j['role'] as String? ?? 'admin'),
        isCurrentDevice: j['isCurrentDevice'] as bool? ?? false,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class BabyAccess {
  final String id;
  final String babyId;
  final String caregiverId;
  CaregiverRole role;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  BabyAccess({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.role,
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
        'role': role.name,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BabyAccess.fromJson(Map<String, dynamic> j) => BabyAccess(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        role: CaregiverRole.values.byName(j['role'] as String),
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class HandoffNote {
  final String id;
  final String babyId;
  final String caregiverId;
  String body;
  DateTime timestamp;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;
  DateTime updatedAt;

  HandoffNote({
    required this.id,
    required this.babyId,
    required this.caregiverId,
    required this.body,
    DateTime? timestamp,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : timestamp = timestamp ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'caregiverId': caregiverId,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HandoffNote.fromJson(Map<String, dynamic> j) => HandoffNote(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        caregiverId: j['caregiverId'] as String,
        body: j['body'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class CaregiverInvite {
  final String id;
  final String babyId;
  final String createdById;
  final String code;        // 8-char alphanumeric
  CaregiverRole grantedRole;
  final DateTime expiresAt;
  bool isRedeemed;
  SyncStatus syncStatus;
  String? remoteId;
  final DateTime createdAt;

  CaregiverInvite({
    required this.id,
    required this.babyId,
    required this.createdById,
    required this.code,
    this.grantedRole = CaregiverRole.caregiver,
    required this.expiresAt,
    this.isRedeemed = false,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isValid => !isRedeemed && expiresAt.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'createdById': createdById,
        'code': code,
        'grantedRole': grantedRole.name,
        'expiresAt': expiresAt.toIso8601String(),
        'isRedeemed': isRedeemed,
        'syncStatus': syncStatus.name,
        'remoteId': remoteId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CaregiverInvite.fromJson(Map<String, dynamic> j) => CaregiverInvite(
        id: j['id'] as String,
        babyId: j['babyId'] as String,
        createdById: j['createdById'] as String,
        code: j['code'] as String,
        grantedRole:
            CaregiverRole.values.byName(j['grantedRole'] as String? ?? 'caregiver'),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        isRedeemed: j['isRedeemed'] as bool? ?? false,
        syncStatus: SyncStatus.values.byName(j['syncStatus'] as String? ?? 'pending'),
        remoteId: j['remoteId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
