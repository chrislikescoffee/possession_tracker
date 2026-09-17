enum SyncOperation { upsert, delete }

enum SyncEntityType {
  library,
  storageLocation,
  item,
  itemType,
  lendingRecord,
  itemList,
}

class SyncQueueItem {
  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload,
    required this.timestamp,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
        orElse: () => SyncEntityType.item,
      ),
      entityId: json['entity_id'] as String,
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == json['operation'],
        orElse: () => SyncOperation.upsert,
      ),
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType.name,
        'entity_id': entityId,
        'operation': operation.name,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };
}

enum SyncState {
  synced,
  syncing,
  pendingSync,
  offline,
  notConfigured,
  error,
}

class SyncStatusInfo {
  final SyncState state;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncStatusInfo({
    required this.state,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  SyncStatusInfo copyWith({
    SyncState? state,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
  }) {
    return SyncStatusInfo(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
    );
  }
}
