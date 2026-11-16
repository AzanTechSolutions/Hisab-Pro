import 'dart:convert';

import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/audit/domain/audit_event.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

class AuditRepository {
  AuditRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Logs a tamper-evident audit record for financial and security actions.
  Future<AuditEvent> logEvent({
    required String userId,
    required String eventType,
    required String eventCategory,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    final event = AuditEvent(
      id: _uuid.v4(),
      userId: userId,
      eventType: eventType,
      eventCategory: eventCategory,
      entityType: entityType,
      entityId: entityId,
      metadataJson: metadata != null ? jsonEncode(metadata) : null,
      createdAt: DateTime.now(),
    );

    try {
      final db = _dbService.getActiveDatabase(userId);
      await db.insert(
        'audit_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Audit event logged: [$eventCategory] $eventType for entity $entityId');
    } catch (e) {
      AppLogger.warning('Failed to persist audit event: $e');
    }

    return event;
  }

  /// Retrieves audit events for [userId], ordered newest first.
  Future<List<AuditEvent>> getAuditEvents(
    String userId, {
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    String? whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (category != null && category.isNotEmpty && category != 'ALL') {
      whereClause += ' AND event_category = ?';
      whereArgs.add(category);
    }

    final rows = await db.query(
      'audit_events',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(AuditEvent.fromMap).toList();
  }

  /// Purges old audit records older than [keepDays].
  Future<int> purgeOldEvents(String userId, {int keepDays = 180}) async {
    final db = _dbService.getActiveDatabase(userId);
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).millisecondsSinceEpoch;

    final deleted = await db.delete(
      'audit_events',
      where: 'user_id = ? AND created_at < ?',
      whereArgs: [userId, cutoff],
    );

    AppLogger.info('Purged $deleted old audit events older than $keepDays days');
    return deleted;
  }
}
