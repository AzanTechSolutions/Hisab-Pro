import 'dart:convert';

/// Represents an immutable audit trail entry for critical financial and security events.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.eventCategory,
    this.entityType,
    this.entityId,
    this.metadataJson,
    required this.createdAt,
  });

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      eventCategory: map['event_category'] as String,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
      metadataJson: map['metadata_json'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  final String id;
  final String userId;
  final String eventType;
  final String eventCategory;
  final String? entityType;
  final String? entityId;
  final String? metadataJson;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'event_category': eventCategory,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata_json': metadataJson,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> get metadata {
    if (metadataJson == null || metadataJson!.isEmpty) return {};
    try {
      return jsonDecode(metadataJson!) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': metadataJson};
    }
  }
}
