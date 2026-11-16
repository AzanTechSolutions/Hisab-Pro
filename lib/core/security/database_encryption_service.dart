import 'dart:convert';

import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';

/// Manages encryption keys for user profiles using Argon2id key wrapping and FlutterSecureStorage.
class DatabaseEncryptionService {
  DatabaseEncryptionService({
    required SecureStorageService secureStorage,
    required KeyDerivationService keyDerivation,
  }) : this._(secureStorage, keyDerivation);

  DatabaseEncryptionService._(this._secureStorage, this._keyDerivation);

  final SecureStorageService _secureStorage;
  final KeyDerivationService _keyDerivation;

  static const String _verifierSentinel = 'HISAB_PRO_VERIFIED_SENTINEL_V1';

  /// Initializes a new random SQLCipher database key for a profile,
  /// encrypts/wraps it with an Argon2id key derived from [userPassword],
  /// and persists the wrapped key, salt, and verification token in secure storage.
  Future<String> initializeProfileDatabaseKey({
    required String profileId,
    required String userPassword,
  }) async {
    final salt = _keyDerivation.buildSalt();
    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: userPassword,
      salt: salt,
    );

    final rawDbKey = AppDatabase.generateSecureRandomKey(length: 32);
    final rawDbKeyBytes = base64Url.decode(rawDbKey);
    final derivedBytes = base64Url.decode(derivedKeyBase64);

    final wrappedKeyBytes = _xorCrypt(rawDbKeyBytes, derivedBytes);
    final wrappedKeyBase64 = base64UrlEncode(wrappedKeyBytes);

    final verifierBytes = _xorCrypt(utf8.encode(_verifierSentinel), derivedBytes);
    final verifierBase64 = base64UrlEncode(verifierBytes);

    final keyAlias = AppDatabase.generateEncryptionKeyAlias(profileId);
    await _secureStorage.write(key: keyAlias, value: wrappedKeyBase64);
    await _secureStorage.write(key: 'db_salt_$profileId', value: salt);
    await _secureStorage.write(key: 'db_verifier_$profileId', value: verifierBase64);

    AppLogger.info('Encrypted database key initialized and wrapped for profile: $profileId');
    return rawDbKey;
  }

  /// Unlocks and returns the raw SQLCipher database key by deriving the key
  /// from [userPassword] and unwrapping the stored key.
  /// Returns null if the password is wrong or keys do not exist.
  Future<String?> unlockProfileDatabaseKey({
    required String profileId,
    required String userPassword,
  }) async {
    final salt = await _secureStorage.read('db_salt_$profileId');
    final keyAlias = AppDatabase.generateEncryptionKeyAlias(profileId);
    final wrappedKeyBase64 = await _secureStorage.read(keyAlias);
    final verifierBase64 = await _secureStorage.read('db_verifier_$profileId');

    if (salt == null || wrappedKeyBase64 == null || verifierBase64 == null) {
      AppLogger.warning('Missing key material for profile: $profileId');
      return null;
    }

    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: userPassword,
      salt: salt,
    );
    final derivedBytes = base64Url.decode(derivedKeyBase64);

    // Verify password first
    final verifierBytes = base64Url.decode(verifierBase64);
    final decryptedVerifier = utf8.decode(
      _xorCrypt(verifierBytes, derivedBytes),
      allowMalformed: true,
    );

    if (decryptedVerifier != _verifierSentinel) {
      AppLogger.warning('Password verification failed for profile: $profileId');
      return null;
    }

    final wrappedBytes = base64Url.decode(wrappedKeyBase64);
    final rawKeyBytes = _xorCrypt(wrappedBytes, derivedBytes);
    return base64UrlEncode(rawKeyBytes);
  }

  /// Verifies if [userPassword] is correct for [profileId] without opening the database.
  Future<bool> verifyPassword({
    required String profileId,
    required String userPassword,
  }) async {
    final salt = await _secureStorage.read('db_salt_$profileId');
    final verifierBase64 = await _secureStorage.read('db_verifier_$profileId');

    if (salt == null || verifierBase64 == null) {
      return false;
    }

    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: userPassword,
      salt: salt,
    );
    final derivedBytes = base64Url.decode(derivedKeyBase64);
    final verifierBytes = base64Url.decode(verifierBase64);
    final decrypted = utf8.decode(
      _xorCrypt(verifierBytes, derivedBytes),
      allowMalformed: true,
    );

    return decrypted == _verifierSentinel;
  }

  /// Stores database key in a biometric-accessible secure storage slot.
  Future<void> enableBiometricUnlock({
    required String profileId,
    required String rawDbKey,
  }) async {
    await _secureStorage.write(
      key: 'db_biometric_$profileId',
      value: rawDbKey,
    );
    AppLogger.info('Biometric unlock enabled for profile: $profileId');
  }

  /// Retrieves the database key via biometric storage.
  Future<String?> unlockWithBiometric({required String profileId}) async {
    return _secureStorage.read('db_biometric_$profileId');
  }

  /// Disables biometric unlock by deleting the biometric key slot.
  Future<void> disableBiometricUnlock({required String profileId}) async {
    await _secureStorage.delete('db_biometric_$profileId');
  }

  /// Securely destroys all encryption keys and salts for [profileId].
  Future<void> destroyProfileDatabaseKey({required String profileId}) async {
    final keyAlias = AppDatabase.generateEncryptionKeyAlias(profileId);
    await _secureStorage.delete(keyAlias);
    await _secureStorage.delete('db_salt_$profileId');
    await _secureStorage.delete('db_verifier_$profileId');
    await _secureStorage.delete('db_biometric_$profileId');

    AppLogger.warning('All encryption keys destroyed for profile: $profileId');
  }

  List<int> _xorCrypt(List<int> data, List<int> key) {
    final result = List<int>.filled(data.length, 0);
    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }
}
