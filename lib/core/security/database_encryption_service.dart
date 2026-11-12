import 'dart:convert';
import 'dart:math';

import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';

class DatabaseEncryptionService {
  DatabaseEncryptionService({
    required this._secureStorage,
    required this._keyDerivation,
  });

  final SecureStorageService _secureStorage;
  final KeyDerivationService _keyDerivation;

  Future<String> initializeProfileDatabaseKey({
    required String profileId,
    required String userPassword,
  }) async {
    final databaseKeyAlias = 'db_key_${profileId}_profile';
    final salt = _keyDerivation.buildSalt();
    final derivedKey = await _keyDerivation.derivePasswordKey(
      password: userPassword,
      salt: salt,
    );

    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final databaseKey = base64UrlEncode(keyBytes);

    await _secureStorage.write(key: databaseKeyAlias, value: databaseKey);
    await _secureStorage.write(key: 'db_salt_$profileId', value: salt);
    await _secureStorage.write(key: 'db_derived_$profileId', value: derivedKey);

    AppLogger.info(
      'Database encryption key initialized for profile: $profileId',
    );

    return databaseKey;
  }

  Future<void> destroyProfileDatabaseKey({required String profileId}) async {
    await _secureStorage.delete('db_key_${profileId}_profile');
    await _secureStorage.delete('db_salt_$profileId');
    await _secureStorage.delete('db_derived_$profileId');

    AppLogger.warning(
      'Database encryption key destroyed for profile: $profileId',
    );
  }
}
