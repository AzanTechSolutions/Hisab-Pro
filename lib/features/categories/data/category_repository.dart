import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/categories/domain/category.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing transaction categories.
class CategoryRepository {
  CategoryRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Retrieves categories for [userId], optionally filtered by [type] ('income' or 'expense').
  Future<List<Category>> getCategories(String userId, {String? type}) async {
    final db = _dbService.getActiveDatabase(userId);
    final where = type != null
        ? 'user_id = ? AND type = ? AND is_active = 1'
        : 'user_id = ? AND is_active = 1';
    final whereArgs = type != null ? [userId, type] : [userId];

    final rows = await db.query(
      'categories',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_default DESC, name ASC',
    );

    return rows.map((r) => Category.fromMap(r)).toList();
  }

  /// Creates a new custom category.
  Future<Category> createCategory({
    required String userId,
    required String name,
    required String type,
    String? colorHex,
    String? iconKey,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure('Category name cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final existing = await db.query(
      'categories',
      where: 'user_id = ? AND LOWER(name) = ? AND type = ?',
      whereArgs: [userId, cleanName.toLowerCase(), type],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationFailure('Category already exists for this type.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final category = Category(
      id: _uuid.v4(),
      userId: userId,
      name: cleanName,
      type: type,
      colorHex: colorHex ?? '#10B981',
      iconKey: iconKey ?? 'category',
      isDefault: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('categories', category.toMap());
    AppLogger.info('Created category ${category.name} ($type) for user $userId');
    return category;
  }

  /// Deletes a category if not in use.
  Future<void> deleteCategory(String userId, String categoryId) async {
    final db = _dbService.getActiveDatabase(userId);
    await db.delete(
      'categories',
      where: 'id = ? AND user_id = ?',
      whereArgs: [categoryId, userId],
    );
  }
}

