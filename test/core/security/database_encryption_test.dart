import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/security/database_encryption_service.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';

void main() {
  group('Security & Encryption Key Lifecycle', () {
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
      'database encryption service initializes, wraps, verifies, and unlocks key',
      () async {
        final secureStorage = _InMemorySecureStorage();
        const keyDerivation = KeyDerivationService();
        final service = DatabaseEncryptionService(
          secureStorage: secureStorage,
          keyDerivation: keyDerivation,
        );

        const profileId = 'profile_alpha';
        const correctPassword = 'StrongPassword123';
        const wrongPassword = 'WrongPassword456';

        // 1. Initialize
        final rawKey = await service.initializeProfileDatabaseKey(
          profileId: profileId,
          userPassword: correctPassword,
        );

        expect(rawKey, isNotEmpty);
        expect(rawKey.length, greaterThan(20));

        // Stored value should NOT be rawKey (it is wrapped)
        final keyAlias = AppDatabase.generateEncryptionKeyAlias(profileId);
        final storedWrapped = await secureStorage.read(keyAlias);
        expect(storedWrapped, isNotNull);
        expect(storedWrapped, isNot(equals(rawKey)));

        // 2. Verify password
        final isCorrectValid = await service.verifyPassword(
          profileId: profileId,
          userPassword: correctPassword,
        );
        expect(isCorrectValid, isTrue);

        final isWrongValid = await service.verifyPassword(
          profileId: profileId,
          userPassword: wrongPassword,
        );
        expect(isWrongValid, isFalse);

        // 3. Unlock with correct password
        final unlockedKey = await service.unlockProfileDatabaseKey(
          profileId: profileId,
          userPassword: correctPassword,
        );
        expect(unlockedKey, equals(rawKey));

        // 4. Unlock with wrong password should fail
        final failedKey = await service.unlockProfileDatabaseKey(
          profileId: profileId,
          userPassword: wrongPassword,
        );
        expect(failedKey, isNull);

        // 5. Destroy keys
        await service.destroyProfileDatabaseKey(profileId: profileId);
        expect(await secureStorage.read(keyAlias), isNull);
        expect(await secureStorage.read('db_salt_$profileId'), isNull);
        expect(await secureStorage.read('db_verifier_$profileId'), isNull);
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
