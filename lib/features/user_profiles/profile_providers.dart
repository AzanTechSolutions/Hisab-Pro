import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/security/database_encryption_service.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/core/security/secure_storage_service.dart';
import 'package:hisab_pro/features/user_profiles/profile_manager_service.dart';
import 'package:hisab_pro/features/user_profiles/user_profile.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final keyDerivationServiceProvider = Provider<KeyDerivationService>((ref) {
  return const KeyDerivationService();
});

final databaseEncryptionServiceProvider = Provider<DatabaseEncryptionService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final keyDerivation = ref.watch(keyDerivationServiceProvider);
  return DatabaseEncryptionService(
    secureStorage: secureStorage,
    keyDerivation: keyDerivation,
  );
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() {
    service.closeAll();
  });
  return service;
});

final profileManagerServiceProvider = Provider<ProfileManagerService>((ref) {
  return ProfileManagerService(
    secureStorage: ref.watch(secureStorageServiceProvider),
    encryptionService: ref.watch(databaseEncryptionServiceProvider),
    databaseService: ref.watch(databaseServiceProvider),
  );
});

/// Lists all user profiles registered on this device.
final profileCatalogProvider = FutureProvider<List<UserProfile>>((ref) async {
  final manager = ref.watch(profileManagerServiceProvider);
  return manager.listProfiles();
});

/// StateNotifier / Notifier holding the active authenticated user profile.
class ActiveProfileNotifier extends StateNotifier<UserProfile?> {
  ActiveProfileNotifier(this.ref) : super(null);

  final Ref ref;

  void setActiveProfile(UserProfile profile) {
    state = profile;
  }

  Future<void> lock() async {
    final profile = state;
    if (profile != null) {
      await ref.read(profileManagerServiceProvider).lockProfile(profile.id);
    }
    state = null;
  }
}

final activeProfileProvider = StateNotifierProvider<ActiveProfileNotifier, UserProfile?>((ref) {
  return ActiveProfileNotifier(ref);
});

/// Provides the active SQLCipher database for the currently authenticated user.
final activeDatabaseProvider = Provider<Database?>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) {
    return null;
  }
  final dbService = ref.watch(databaseServiceProvider);
  if (dbService.isProfileDatabaseOpen(activeProfile.id)) {
    return dbService.getActiveDatabase(activeProfile.id);
  }
  return null;
});

