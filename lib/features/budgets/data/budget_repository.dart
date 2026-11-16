import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/budgets/domain/budget.dart';
import 'package:uuid/uuid.dart';

/// Repository for monthly budgets and category allocation limits.
class BudgetRepository {
  BudgetRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Retrieves the budget for a specific month and year with live calculated spent values.
  Future<Budget?> getBudgetForMonth(
    String userId,
    int year,
    int month,
  ) async {
    final db = _dbService.getActiveDatabase(userId);

    // 1. Fetch budget record
    final budgetRows = await db.query(
      'budgets',
      where: 'user_id = ? AND budget_year = ? AND budget_month = ?',
      whereArgs: [userId, year, month],
      limit: 1,
    );

    if (budgetRows.isEmpty) return null;

    final budgetRow = budgetRows.first;
    final budgetId = budgetRow['id'] as String;

    // Calculate start and end timestamp of the month
    final startOfMonth = DateTime(year, month, 1).millisecondsSinceEpoch;
    final endOfMonth = (month == 12)
        ? DateTime(year + 1, 1, 1).millisecondsSinceEpoch - 1
        : DateTime(year, month + 1, 1).millisecondsSinceEpoch - 1;

    // 2. Calculate total expenses in this month
    final totalSpentResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total_spent 
      FROM transactions 
      WHERE user_id = ? AND type = 'expense' AND status = 'posted'
        AND transaction_date >= ? AND transaction_date <= ?
      ''',
      [userId, startOfMonth, endOfMonth],
    );
    final totalSpentMinor = (totalSpentResult.first['total_spent'] as int?) ?? 0;

    // 3. Fetch category allocations joined with category details and live category spent
    final allocationsResult = await db.rawQuery(
      '''
      SELECT 
        bc.*,
        c.name AS category_name,
        c.color_hex AS category_color,
        c.icon_key AS category_icon,
        COALESCE((
          SELECT SUM(t.amount_minor) 
          FROM transactions t 
          WHERE t.user_id = bc.user_id AND t.category_id = bc.category_id 
            AND t.type = 'expense' AND t.status = 'posted'
            AND t.transaction_date >= ? AND t.transaction_date <= ?
        ), 0) AS category_spent_minor
      FROM budget_categories bc
      LEFT JOIN categories c ON bc.category_id = c.id
      WHERE bc.user_id = ? AND bc.budget_id = ?
      ORDER BY bc.limit_minor DESC
      ''',
      [startOfMonth, endOfMonth, userId, budgetId],
    );

    final allocations = allocationsResult.map((row) {
      return BudgetCategoryAllocation.fromMap(
        row,
        spentMinor: (row['category_spent_minor'] as int?) ?? 0,
      );
    }).toList();

    return Budget.fromMap(
      budgetRow,
      spentMinor: totalSpentMinor,
      allocations: allocations,
    );
  }

  /// Sets or updates a monthly budget with category allocations.
  Future<Budget> setMonthlyBudget({
    required String userId,
    required String name,
    required int year,
    required int month,
    required int totalLimitMinor,
    int notificationThresholdPercent = 80,
    Map<String, int> categoryLimitsMinor = const {},
  }) async {
    if (totalLimitMinor <= 0) {
      throw const ValidationFailure('Monthly budget limit must be greater than zero.');
    }
    if (month < 1 || month > 12) {
      throw const ValidationFailure('Invalid month value.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if budget exists for this month/year
    final existing = await db.query(
      'budgets',
      where: 'user_id = ? AND budget_year = ? AND budget_month = ?',
      whereArgs: [userId, year, month],
      limit: 1,
    );

    String budgetId;

    await db.transaction((txn) async {
      if (existing.isEmpty) {
        budgetId = _uuid.v4();
        await txn.insert('budgets', {
          'id': budgetId,
          'user_id': userId,
          'name': name.trim(),
          'budget_month': month,
          'budget_year': year,
          'total_limit_minor': totalLimitMinor,
          'currency': 'PKR',
          'notification_threshold_percent': notificationThresholdPercent,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        budgetId = existing.first['id'] as String;
        await txn.update(
          'budgets',
          {
            'name': name.trim(),
            'total_limit_minor': totalLimitMinor,
            'notification_threshold_percent': notificationThresholdPercent,
            'updated_at': now,
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [budgetId, userId],
        );
      }

      // Upsert category allocations
      for (final entry in categoryLimitsMinor.entries) {
        final categoryId = entry.key;
        final limit = entry.value;

        final existingAlloc = await txn.query(
          'budget_categories',
          where: 'user_id = ? AND budget_id = ? AND category_id = ?',
          whereArgs: [userId, budgetId, categoryId],
          limit: 1,
        );

        if (existingAlloc.isEmpty) {
          await txn.insert('budget_categories', {
            'id': _uuid.v4(),
            'user_id': userId,
            'budget_id': budgetId,
            'category_id': categoryId,
            'limit_minor': limit,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          await txn.update(
            'budget_categories',
            {
              'limit_minor': limit,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existingAlloc.first['id']],
          );
        }
      }
    });

    AppLogger.info('Set monthly budget for $month/$year: $totalLimitMinor PKR');
    return (await getBudgetForMonth(userId, year, month))!;
  }

  /// Deletes a monthly budget record and its category allocations.
  Future<void> deleteBudget(String userId, String budgetId) async {
    final db = _dbService.getActiveDatabase(userId);
    await db.delete(
      'budgets',
      where: 'id = ? AND user_id = ?',
      whereArgs: [budgetId, userId],
    );
  }
}

