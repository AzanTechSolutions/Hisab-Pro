import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/features/backup/data/backup_service.dart';
import 'package:hisab_pro/features/backup/domain/backup_manifest.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockTransaction extends Mock implements Transaction {}

class MockDatabase extends Mock implements Database {
  final MockTransaction _mockTxn;
  MockDatabase(this._mockTxn);

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) {
    return action(_mockTxn);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  group('Phase 6: Encrypted Backup & Restore Service Tests', () {
    late MockDatabaseService mockDbService;
    late MockDatabase mockDb;
    late MockTransaction mockTxn;
    late BackupService backupService;
    late Directory tempDir;
    const testProfileId = 'profile_test_backup_01';
    const testPassword = 'MySecretBackupPassword123!';

    setUp(() async {
      mockDbService = MockDatabaseService();
      mockTxn = MockTransaction();
      mockDb = MockDatabase(mockTxn);
      tempDir = await Directory.systemTemp.createTemp('hisab_backup_test_');

      when(() => mockDbService.getActiveDatabase(testProfileId)).thenReturn(mockDb);

      backupService = BackupService(
        databaseService: mockDbService,
        keyDerivation: const KeyDerivationService(),
      );

      // Default mock query returns for tables
      for (final table in [
        'accounts',
        'categories',
        'people',
        'attachments',
        'transactions',
        'transfers',
        'loans',
        'loan_repayments',
        'budgets',
        'budget_categories',
        'reminders',
        'app_settings',
      ]) {
        if (table == 'accounts') {
          when(() => mockDb.query(table)).thenAnswer((_) async => [
            {
              'id': 'acc_01',
              'user_id': testProfileId,
              'name': 'Primary Cash',
              'account_type': 'cash',
              'currency': 'PKR',
              'opening_balance_minor': 1000000,
              'current_balance_minor': 850000,
              'is_active': 1,
              'created_at': 1700000000000,
              'updated_at': 1700000000000,
            }
          ]);
        } else if (table == 'transactions') {
          when(() => mockDb.query(table)).thenAnswer((_) async => [
            {
              'id': 'tx_01',
              'user_id': testProfileId,
              'account_id': 'acc_01',
              'category_id': 'cat_01',
              'type': 'expense',
              'title': 'Weekly Market',
              'amount_minor': 150000,
              'payment_method': 'Cash',
              'transaction_date': 1700000000000,
              'status': 'posted',
              'created_at': 1700000000000,
              'updated_at': 1700000000000,
            }
          ]);
        } else {
          when(() => mockDb.query(table)).thenAnswer((_) async => []);
        }
      }

      // Mock PRAGMA integrity_check
      when(() => mockDb.rawQuery('PRAGMA integrity_check'))
          .thenAnswer((_) async => [{'integrity_check': 'ok'}]);

      when(() => mockTxn.delete(any())).thenAnswer((_) async => 0);
      when(() => mockTxn.insert(any(), any(), conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .thenAnswer((_) async => 1);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('BackupManifest serializes and deserializes accurately', () {
      final manifest = BackupManifest(
        manifestVersion: 1,
        profileId: testProfileId,
        profileName: 'Primary User',
        createdAt: DateTime.utc(2026, 11, 16, 12, 0, 0),
        appVersion: '1.0.0',
        schemaVersion: 1,
        salt: 'dGVzdF9zYWx0XzEyMzQ1Ng==',
        checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        tableCounts: {'accounts': 1, 'transactions': 1},
      );

      final encoded = manifest.toEncodedJson();
      final decoded = BackupManifest.fromEncodedJson(encoded);

      expect(decoded.profileId, equals(testProfileId));
      expect(decoded.profileName, equals('Primary User'));
      expect(decoded.totalRecords, equals(2));
      expect(decoded.checksum, equals(manifest.checksum));
    });

    test('Successfully exports encrypted backup file with Argon2id + HMAC', () async {
      final backupFile = await backupService.createEncryptedBackup(
        profileId: testProfileId,
        profileName: 'Primary User',
        backupPassword: testPassword,
        targetDirectoryPath: tempDir.path,
      );

      expect(backupFile.existsSync(), isTrue);
      final content = backupFile.readAsStringSync();
      expect(content.startsWith('HISAB_BACKUP_CONTAINER_V1'), isTrue);
      expect(content.contains('---HISAB_PAYLOAD---'), isTrue);
      expect(content.contains('---HISAB_HMAC---'), isTrue);
    });

    test('Verifies valid backup file and returns manifest metadata', () async {
      final backupFile = await backupService.createEncryptedBackup(
        profileId: testProfileId,
        profileName: 'Primary User',
        backupPassword: testPassword,
        targetDirectoryPath: tempDir.path,
      );

      final content = backupFile.readAsStringSync();
      final manifest = await backupService.verifyBackup(
        fileContent: content,
        backupPassword: testPassword,
      );

      expect(manifest.profileId, equals(testProfileId));
      expect(manifest.tableCounts['accounts'], equals(1));
      expect(manifest.tableCounts['transactions'], equals(1));
      expect(manifest.totalRecords, equals(2));
    });

    test('Throws BackupException when wrong backup password is provided', () async {
      final backupFile = await backupService.createEncryptedBackup(
        profileId: testProfileId,
        profileName: 'Primary User',
        backupPassword: testPassword,
        targetDirectoryPath: tempDir.path,
      );

      final content = backupFile.readAsStringSync();
      expect(
        () => backupService.verifyBackup(
          fileContent: content,
          backupPassword: 'WrongPassword999!',
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('Restores database from verified backup with integrity check', () async {
      final backupFile = await backupService.createEncryptedBackup(
        profileId: testProfileId,
        profileName: 'Primary User',
        backupPassword: testPassword,
        targetDirectoryPath: tempDir.path,
      );

      final content = backupFile.readAsStringSync();
      final result = await backupService.restoreBackup(
        fileContent: content,
        backupPassword: testPassword,
        currentProfileId: testProfileId,
        createSafetyBackup: false,
      );

      expect(result['totalRecords'], equals(2));
      expect(result['profileId'], equals(testProfileId));

      verify(() => mockTxn.delete(any())).called(12); // All tables cleared
      verify(() => mockTxn.insert(any(), any(), conflictAlgorithm: any(named: 'conflictAlgorithm'))).called(2);
      verify(() => mockDb.rawQuery('PRAGMA integrity_check')).called(2);
    });
  });
}
