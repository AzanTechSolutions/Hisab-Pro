import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/security/database_encryption_service.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';

void main() {
  group('Security foundation', () {
    test('database key alias and filename are unique per profile', () {
      final profileA = AppDatabase.generateDatabaseFilename('profile_one');
      final profileB = AppDatabase.generateDatabaseFilename('profile_two');

      expect(profileA, isNot(equals(profileB)));
      expect(
        AppDatabase.generateEncryptionKeyAlias('profile_one'),
        'profile_profile_one_db_key',
      );
    });

    test('key derivation service produces a usable derived secret', () async {
      const keyService = KeyDerivationService();
      final salt = keyService.buildSalt();
      final derived = await keyService.derivePasswordKey(
        password: 'StrongPassword123',
        salt: salt,
      );

      expect(derived, isNotEmpty);
      expect(derived.length, greaterThan(20));
    });

    test(
      'database encryption service creates a profile-specific database key',
      () async {
        final secureStorage = _InMemorySecureStorage();
        final keyDerivation = const KeyDerivationService();
        final service = DatabaseEncryptionService(
          secureStorage: secureStorage,
          keyDerivation: keyDerivation,
        );

        final key = await service.initializeProfileDatabaseKey(
          profileId: 'profile_one',
          userPassword: 'StrongPassword123',
        );

        expect(key, isNotEmpty);
        expect(key.length, greaterThan(20));
        expect(await secureStorage.read('db_key_profile_one_profile'), key);
      },
    );
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
}
