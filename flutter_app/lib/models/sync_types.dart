import 'package:uuid/uuid.dart';

enum SyncStatus { pending, synced, failed, deleted }

enum SyncOperationType { insert, update, delete }

class SyncOperation {
  final String id;
  final String modelType;
  final String modelId;
  final SyncOperationType operation;
  final Map<String, dynamic> payload;
  int retryCount;
  DateTime? lastAttemptAt;
  final DateTime createdAt;

  SyncOperation({
    required this.modelType,
    required this.modelId,
    required this.operation,
    this.payload = const {},
  })  : id = const Uuid().v4(),
        retryCount = 0,
        createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelType': modelType,
        'modelId': modelId,
        'operation': operation.name,
        'payload': payload,
        'retryCount': retryCount,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> j) {
    final op = SyncOperation(
      modelType: j['modelType'] as String,
      modelId: j['modelId'] as String,
      operation: SyncOperationType.values.byName(j['operation'] as String),
      payload: (j['payload'] as Map<String, dynamic>?) ?? {},
    );
    op.retryCount = j['retryCount'] as int? ?? 0;
    final lat = j['lastAttemptAt'];
    if (lat != null) op.lastAttemptAt = DateTime.parse(lat as String);
    return op;
  }
}
