import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/database/database_service.dart';

void main() {
  group('Database service', () {
    test('bootstrap profile creates a versioned database config', () async {
      const service = DatabaseService();

      final config = await service.bootstrapProfile(profileId: 'user_alpha');

      expect(config.profileId, 'user_alpha');
      expect(config.schemaVersion, DatabaseSchemaVersion.current);
      expect(config.databaseFilename, endsWith('_hisab_pro.db'));
      expect(config.databaseFilename, contains('user_alpha'));
    });

    test('integrity validation checks the expected required schema', () async {
      const service = DatabaseService();

      final result = await service.verifyIntegrity();

      expect(result.isValid, isTrue);
      expect(result.checkedTables, isNotEmpty);
      expect(result.checkedTables, containsAll(AppDatabase.requiredEntities.map((entity) => entity.name)));
    });
  });
}
