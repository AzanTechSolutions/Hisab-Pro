import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/features/audit/data/audit_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockDatabase extends Mock implements Database {}

void main() {
  setUpAll(() {
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  group('Phase 7: Audit Logging Engine Tests', () {
    late MockDatabaseService mockDbService;
    late MockDatabase mockDb;
    late AuditRepository auditRepo;
    const testUserId = 'audit_test_user_01';

    setUp(() {
      mockDbService = MockDatabaseService();
      mockDb = MockDatabase();
      auditRepo = AuditRepository(databaseService: mockDbService);

      when(() => mockDbService.getActiveDatabase(testUserId)).thenReturn(mockDb);
    });

    test('Logs audit event with metadata and inserts into audit_events table', () async {
      when(() => mockDb.insert(
        'audit_events',
        any(),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      )).thenAnswer((_) async => 1);

      final event = await auditRepo.logEvent(
        userId: testUserId,
        eventType: 'transaction_deleted',
        eventCategory: 'TRANSACTION',
        entityType: 'transactions',
        entityId: 'tx_999',
        metadata: {'amount_minor': 50000, 'reversal': true},
      );

      expect(event.userId, equals(testUserId));
      expect(event.eventType, equals('transaction_deleted'));
      expect(event.eventCategory, equals('TRANSACTION'));
      expect(event.entityId, equals('tx_999'));
      expect(event.metadata['reversal'], isTrue);

      verify(() => mockDb.insert(
        'audit_events',
        any(that: predicate((Map<String, dynamic> map) =>
          map['user_id'] == testUserId &&
          map['event_type'] == 'transaction_deleted' &&
          map['entity_id'] == 'tx_999')),
        conflictAlgorithm: any(named: 'conflictAlgorithm'),
      )).called(1);
    });

    test('Retrieves audit events filtered by category', () async {
      when(() => mockDb.query(
        'audit_events',
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        orderBy: any(named: 'orderBy'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'ev_1',
          'user_id': testUserId,
          'event_type': 'login_biometric',
          'event_category': 'SECURITY',
          'entity_type': 'user_profiles',
          'entity_id': testUserId,
          'metadata_json': '{"method":"biometric"}',
          'created_at': 1700000000000,
        }
      ]);

      final events = await auditRepo.getAuditEvents(testUserId, category: 'SECURITY');

      expect(events.length, equals(1));
      expect(events.first.eventType, equals('login_biometric'));
      expect(events.first.eventCategory, equals('SECURITY'));
    });

    test('Purges old audit events older than specified threshold', () async {
      when(() => mockDb.delete(
        'audit_events',
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      )).thenAnswer((_) async => 5);

      final purgedCount = await auditRepo.purgeOldEvents(testUserId, keepDays: 90);

      expect(purgedCount, equals(5));
      verify(() => mockDb.delete(
        'audit_events',
        where: 'user_id = ? AND created_at < ?',
        whereArgs: any(named: 'whereArgs'),
      )).called(1);
    });
  });
}
