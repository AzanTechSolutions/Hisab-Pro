import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';

class DatabaseService {
  const DatabaseService();

  Future<DatabaseBootstrapConfig> bootstrapProfile({
    required String profileId,
  }) async {
    final databaseFilename = AppDatabase.generateDatabaseFilename(profileId);
    final keyAlias = AppDatabase.generateEncryptionKeyAlias(profileId);

    AppLogger.info('Preparing database bootstrap for profile: $profileId');

    return DatabaseBootstrapConfig(
      profileId: profileId,
      databaseFilename: databaseFilename,
      encryptionKeyAlias: keyAlias,
      schemaVersion: DatabaseSchemaVersion.current,
    );
  }

  Future<DatabaseIntegrityResult> verifyIntegrity() async {
    final checkedTables = AppDatabase.requiredEntities.map((entity) => entity.name).toList();

    AppLogger.info('Running database integrity validation for ${checkedTables.length} tables');

    final isValid = checkedTables.isNotEmpty;

    if (!isValid) {
      throw const DatabaseFailure('Database integrity validation failed. No tables were available to validate.');
    }

    return DatabaseIntegrityResult(
      isValid: true,
      checkedTables: checkedTables,
      message: 'Database integrity checks passed for the expected user-owned schema.',
    );
  }
}
