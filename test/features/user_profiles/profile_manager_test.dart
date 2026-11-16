import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/security/database_encryption_service.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';
import 'package:hisab_pro/features/user_profiles/profile_manager_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Manager & Multi-User Isolation', () {
    late _InMemorySecureStorage secureStorage;
    late KeyDerivationService keyDerivation;
    late DatabaseEncryptionService encryptionService;
    late _FakeDatabaseService databaseService;
    late ProfileManagerService profileManager;

    setUp(() {
      secureStorage = _InMemorySecureStorage();
      keyDerivation = const KeyDerivationService();
      encryptionService = DatabaseEncryptionService(
        secureStorage: secureStorage,
        keyDerivation: keyDerivation,
      );
      databaseService = _FakeDatabaseService();
      profileManager = ProfileManagerService(
        secureStorage: secureStorage,
        encryptionService: encryptionService,
        databaseService: databaseService,
      );
    });

    test('listProfiles returns empty when no profiles exist', () async {
      final profiles = await profileManager.listProfiles();
      expect(profiles, isEmpty);
    });

    test('createProfile saves catalog and initializes encrypted keys', () async {
      final profile = await profileManager.createProfile(
        username: 'azan_test',
        fullName: 'Muhammad Azan',
        pin: '1234',
        biometricEnabled: true,
      );

      expect(profile.id, isNotEmpty);
      expect(profile.username, 'azan_test');
      expect(profile.fullName, 'Muhammad Azan');
      expect(profile.biometricEnabled, isTrue);

      final list = await profileManager.listProfiles();
      expect(list.length, equals(1));
      expect(list.first.username, 'azan_test');

      // Verify that database was opened with an encryption key
      expect(databaseService.openedProfiles, contains(profile.id));
    });

    test('cannot create duplicate username', () async {
      await profileManager.createProfile(
        username: 'john_doe',
        fullName: 'John Doe',
        pin: '1234',
      );

      expect(
        () => profileManager.createProfile(
          username: 'john_doe',
          fullName: 'Another John',
          pin: '5678',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteProfile removes from catalog, closes db, and destroys keys', () async {
      final profile = await profileManager.createProfile(
        username: 'delete_me',
        fullName: 'To Delete',
        pin: '1111',
      );

      expect((await profileManager.listProfiles()).length, equals(1));

      await profileManager.deleteProfile(profile.id);

      expect((await profileManager.listProfiles()), isEmpty);
      expect(databaseService.deletedProfiles, contains(profile.id));
      expect(await secureStorage.read('profile_${profile.id}_db_key'), isNull);
    });
  });
}

class _InMemorySecureStorage extends SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _values.clear();
  }
}

class _FakeDatabaseService extends DatabaseService {
  final Set<String> openedProfiles = {};
  final Set<String> deletedProfiles = {};

  @override
  Future<Database> openProfileDatabase({
    required String profileId,
    required String encryptionKey,
    String? overridePath,
  }) async {
    openedProfiles.add(profileId);
    return _FakeDatabase(profileId);
  }

  @override
  Future<void> deleteProfileDatabase({
    required String profileId,
    String? overridePath,
  }) async {
    deletedProfiles.add(profileId);
  }

  @override
  Future<void> closeProfileDatabase(String profileId) async {
    openedProfiles.remove(profileId);
  }
}

class _FakeDatabase extends Mock implements Database {
  _FakeDatabase(this.profileId);
  final String profileId;
  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    return action(_FakeTransaction(this));
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    return [
      {
        'id': profileId,
        'username': 'test_user',
        'full_name': 'Test User',
        'biometric_enabled': 0,
        'lock_enabled': 1,
        'inactivity_timeout_minutes': 5,
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }
    ];
  }
}

class _FakeTransaction extends Mock implements Transaction {
  _FakeTransaction(this.db);
  final _FakeDatabase db;

  @override
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    db.tables.putIfAbsent(table, () => []).add(values);
    return 1;
  }
}

