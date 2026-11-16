import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/database/database_service.dart';

void main() {
  group('Database service', () {
    test('bootstrap profile creates a versioned database config', () async {
      final service = DatabaseService();

      final config = await service.bootstrapProfile(profileId: 'user_alpha');

      expect(config.profileId, 'user_alpha');
      expect(config.schemaVersion, DatabaseSchemaVersion.current);
      expect(config.databaseFilename, endsWith('.db'));
      expect(config.databaseFilename, contains('user_alpha'));
      expect(config.encryptionKeyAlias, 'profile_user_alpha_db_key');
    });

    test('integrity validation checks the expected required schema', () async {
      final service = DatabaseService();

      final result = await service.verifyIntegrity();

      expect(result.isValid, isTrue);
      expect(result.checkedTables, isNotEmpty);
      expect(
        result.checkedTables,
        containsAll(AppDatabase.requiredEntities.map((entity) => entity.name)),
      );
    });

    test('isProfileDatabaseOpen returns false before database is opened', () {
      final service = DatabaseService();
      expect(service.isProfileDatabaseOpen('user_alpha'), isFalse);
    });
  });
}
