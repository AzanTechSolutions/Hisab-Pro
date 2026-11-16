import 'dart:convert';

import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/core/security/database_encryption_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';
import 'package:hisab_pro/features/user_profiles/user_profile.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates multi-profile lifecycle, catalog persistence, and profile isolation.
class ProfileManagerService {
  ProfileManagerService({
    required SecureStorageService secureStorage,
    required DatabaseEncryptionService encryptionService,
    required DatabaseService databaseService,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _databaseService = databaseService;

  final SecureStorageService _secureStorage;
  final DatabaseEncryptionService _encryptionService;
  final DatabaseService _databaseService;

  static const String _catalogKey = 'hisab_pro_profile_catalog';
  final _uuid = const Uuid();

  /// Lists all registered profiles on the device from the protected catalog.
  Future<List<UserProfile>> listProfiles() async {
    final raw = await _secureStorage.read(_catalogKey);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => UserProfile.fromCatalogMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to parse profile catalog: $e');
      return [];
    }
  }

  /// Creates a new user profile with its own isolated SQLCipher database.
  Future<UserProfile> createProfile({
    required String username,
    required String fullName,
    required String pin,
    String? avatarPath,
    bool biometricEnabled = false,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || pin.length < 4) {
      throw const ValidationFailure('Username and minimum 4-digit PIN are required.');
    }

    final existingProfiles = await listProfiles();
    if (existingProfiles.any((p) => p.username.toLowerCase() == cleanUsername)) {
      throw const ValidationFailure('Username is already taken on this device.');
    }

    final profileId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Initialize wrapped database encryption key
    final rawDbKey = await _encryptionService.initializeProfileDatabaseKey(
      profileId: profileId,
      userPassword: pin,
    );

    if (biometricEnabled) {
      await _encryptionService.enableBiometricUnlock(
        profileId: profileId,
        rawDbKey: rawDbKey,
      );
    }

    // 2. Open and bootstrap database
    final db = await _databaseService.openProfileDatabase(
      profileId: profileId,
      encryptionKey: rawDbKey,
    );

    final profile = UserProfile(
      id: profileId,
      username: cleanUsername,
      fullName: fullName.trim(),
      avatarPath: avatarPath,
      biometricEnabled: biometricEnabled,
      lockEnabled: true,
      inactivityTimeoutMinutes: 5,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: now,
    );

    // 3. Insert profile into database and seed defaults in transaction
    await db.transaction((txn) async {
      await txn.insert('user_profiles', {
        ...profile.toMap(),
        'profile_pin_hash': 'PBKDF2_SHA256_PROTECTED',
        'salt': 'STORED_IN_KEYSTORE',
        'kdf_params': 'pbkdf2:sha256,iter:10000',
      });

      await txn.insert('app_settings', {
        'id': _uuid.v4(),
        'user_id': profileId,
        'theme_mode': 'system',
        'accent_color': null,
        'locale': 'en',
        'default_currency': 'PKR',
        'lock_timeout_minutes': 5,
        'biometric_enabled': biometricEnabled ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });

      // Seed default accounts
      await _seedDefaultAccounts(txn, profileId, now);

      // Seed default categories
      await _seedDefaultCategories(txn, profileId, now);

      // Log audit event
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': profileId,
        'event_type': 'profile_created',
        'event_category': 'security',
        'entity_type': 'user_profiles',
        'entity_id': profileId,
        'metadata_json': jsonEncode({'username': cleanUsername}),
        'created_at': now,
      });
    });

    // 4. Update profile catalog
    final updatedCatalog = [...existingProfiles, profile];
    await _saveCatalog(updatedCatalog);

    AppLogger.info('Successfully created isolated profile: $profileId ($cleanUsername)');
    return profile;
  }

  /// Unlocks profile database with PIN and returns the profile.
  Future<UserProfile?> unlockProfileWithPin({
    required String profileId,
    required String pin,
  }) async {
    final rawDbKey = await _encryptionService.unlockProfileDatabaseKey(
      profileId: profileId,
      userPassword: pin,
    );

    if (rawDbKey == null) {
      return null;
    }

    final db = await _databaseService.openProfileDatabase(
      profileId: profileId,
      encryptionKey: rawDbKey,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'user_profiles',
      {'last_login_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [profileId],
    );

    final result = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return UserProfile.fromMap(result.first);
  }

  /// Unlocks profile database with biometric key and returns the profile.
  Future<UserProfile?> unlockProfileWithBiometrics({
    required String profileId,
  }) async {
    final rawDbKey = await _encryptionService.unlockWithBiometric(
      profileId: profileId,
    );

    if (rawDbKey == null) {
      return null;
    }

    final db = await _databaseService.openProfileDatabase(
      profileId: profileId,
      encryptionKey: rawDbKey,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'user_profiles',
      {'last_login_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [profileId],
    );

    final result = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return UserProfile.fromMap(result.first);
  }

  /// Locks and switches out the active profile.
  Future<void> lockProfile(String profileId) async {
    await _databaseService.closeProfileDatabase(profileId);
    AppLogger.info('Profile locked: $profileId');
  }

  /// Permanently deletes a profile, its database file, and its encryption keys.
  Future<void> deleteProfile(String profileId) async {
    // 1. Delete database file
    await _databaseService.deleteProfileDatabase(profileId: profileId);

    // 2. Destroy keys in secure storage
    await _encryptionService.destroyProfileDatabaseKey(profileId: profileId);

    // 3. Remove from catalog
    final profiles = await listProfiles();
    final updated = profiles.where((p) => p.id != profileId).toList();
    await _saveCatalog(updated);

    AppLogger.warning('Profile permanently deleted: $profileId');
  }

  Future<void> _saveCatalog(List<UserProfile> profiles) async {
    final encoded = jsonEncode(profiles.map((p) => p.toCatalogMap()).toList());
    await _secureStorage.write(key: _catalogKey, value: encoded);
  }

  Future<void> _seedDefaultAccounts(
    Transaction txn,
    String userId,
    int now,
  ) async {
    final defaultAccounts = [
      {'name': 'Cash', 'type': 'cash'},
      {'name': 'Bank Account', 'type': 'bank'},
      {'name': 'Wallet (Easypaisa/JazzCash)', 'type': 'wallet'},
    ];

    for (final acc in defaultAccounts) {
      await txn.insert('accounts', {
        'id': _uuid.v4(),
        'user_id': userId,
        'name': acc['name'],
        'account_type': acc['type'],
        'currency': 'PKR',
        'opening_balance_minor': 0,
        'current_balance_minor': 0,
        'is_archived': 0,
        'notes': 'Default account',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _seedDefaultCategories(
    Transaction txn,
    String userId,
    int now,
  ) async {
    final defaultIncome = [
      {'name': 'Salary', 'icon': 'payments', 'color': '#10B981'},
      {'name': 'Business', 'icon': 'store', 'color': '#3B82F6'},
      {'name': 'Freelancing', 'icon': 'laptop', 'color': '#8B5CF6'},
      {'name': 'Investment', 'icon': 'trending_up', 'color': '#06B6D4'},
      {'name': 'Rental Income', 'icon': 'home', 'color': '#F59E0B'},
      {'name': 'Gifts', 'icon': 'card_giftcard', 'color': '#EC4899'},
      {'name': 'Other Income', 'icon': 'attach_money', 'color': '#64748B'},
    ];

    final defaultExpenses = [
      {'name': 'Food & Dining', 'icon': 'restaurant', 'color': '#EF4444'},
      {'name': 'Groceries', 'icon': 'shopping_basket', 'color': '#F97316'},
      {'name': 'Transportation', 'icon': 'directions_car', 'color': '#F59E0B'},
      {'name': 'Rent', 'icon': 'apartment', 'color': '#EAB308'},
      {'name': 'Bills & Utilities', 'icon': 'receipt', 'color': '#10B981'},
      {'name': 'Shopping', 'icon': 'shopping_cart', 'color': '#06B6D4'},
      {'name': 'Healthcare', 'icon': 'local_hospital', 'color': '#3B82F6'},
      {'name': 'Education', 'icon': 'school', 'color': '#6366F1'},
      {'name': 'Entertainment', 'icon': 'movie', 'color': '#8B5CF6'},
      {'name': 'Travel', 'icon': 'flight', 'color': '#EC4899'},
      {'name': 'Other Expense', 'icon': 'more_horiz', 'color': '#64748B'},
    ];

    for (final cat in defaultIncome) {
      await txn.insert('categories', {
        'id': _uuid.v4(),
        'user_id': userId,
        'name': cat['name'],
        'type': 'income',
        'color_hex': cat['color'],
        'icon_key': cat['icon'],
        'is_default': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    for (final cat in defaultExpenses) {
      await txn.insert('categories', {
        'id': _uuid.v4(),
        'user_id': userId,
        'name': cat['name'],
        'type': 'expense',
        'color_hex': cat['color'],
        'icon_key': cat['icon'],
        'is_default': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}

