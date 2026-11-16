import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SettingsRepository {
  SettingsRepository({required DatabaseService databaseService})
      : _databaseService = databaseService;

  final DatabaseService _databaseService;

  Future<String?> getSetting({
    required String userId,
    required String key,
  }) async {
    final db = _databaseService.getActiveDatabase(userId);
    final results = await db.query(
      'app_settings',
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> saveSetting({
    required String userId,
    required String key,
    required String value,
  }) async {
    final db = _databaseService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'app_settings',
      {
        'user_id': userId,
        'key': key,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.info('Setting saved: $key = $value for user $userId');
  }

  Future<Map<String, String>> getAllSettings({required String userId}) async {
    final db = _databaseService.getActiveDatabase(userId);
    final results = await db.query(
      'app_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final Map<String, String> settings = {};
    for (final row in results) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }
}

