import 'package:hisab_pro/core/database/app_database.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';

class DatabaseMigration {
  const DatabaseMigration();

  DatabaseMigrationPlan plan({required int fromVersion, required int toVersion}) {
    return DatabaseMigrationPlan(fromVersion: fromVersion, toVersion: toVersion);
  }

  Future<void> apply({required DatabaseMigrationPlan migrationPlan}) async {
    final steps = migrationPlan.steps;

    AppLogger.info('Applying ${steps.length} database migration steps');

    for (final step in steps) {
      AppLogger.debug(step);
    }
  }
}
