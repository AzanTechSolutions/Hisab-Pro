import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/features/budgets/data/budget_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 5: Budget & Spending Limit Calculations', () {
    late Database db;
    late DatabaseService dbService;
    late BudgetRepository budgetRepo;
    const userId = 'test_user_p5_budget';

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE budgets (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          budget_month INTEGER NOT NULL,
          budget_year INTEGER NOT NULL,
          total_limit_minor INTEGER NOT NULL,
          currency TEXT NOT NULL DEFAULT 'PKR',
          notification_threshold_percent INTEGER DEFAULT 80,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE budget_categories (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          budget_id TEXT NOT NULL,
          category_id TEXT NOT NULL,
          limit_minor INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          color_hex TEXT,
          icon_key TEXT,
          is_default INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          category_id TEXT,
          person_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          payment_method TEXT,
          transaction_date INTEGER NOT NULL,
          transaction_time INTEGER,
          notes TEXT,
          attachment_id TEXT,
          status TEXT NOT NULL DEFAULT 'posted',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      dbService = _TestDatabaseService(db);
      budgetRepo = BudgetRepository(databaseService: dbService);
    });

    tearDown(() async {
      await db.close();
    });

    test('Sets and retrieves monthly budget with accurate live spent and remaining', () async {
      final now = DateTime(2026, 11, 15);
      final month = now.month;
      final year = now.year;

      // Set monthly budget of 50,000 PKR (5,000,000 minor)
      await budgetRepo.setMonthlyBudget(
        userId: userId,
        name: 'November Budget',
        year: year,
        month: month,
        totalLimitMinor: 5000000,
        notificationThresholdPercent: 80,
      );

      // Insert an expense of 20,000 PKR in this month
      await db.insert('transactions', {
        'id': 'tx_1',
        'user_id': userId,
        'account_id': 'acc_1',
        'category_id': 'cat_food',
        'type': 'expense',
        'title': 'Groceries',
        'amount_minor': 2000000, // 20k
        'transaction_date': DateTime(2026, 11, 10).millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Insert another expense of 10,000 PKR in this month
      await db.insert('transactions', {
        'id': 'tx_2',
        'user_id': userId,
        'account_id': 'acc_1',
        'category_id': 'cat_fuel',
        'type': 'expense',
        'title': 'Fuel',
        'amount_minor': 1000000, // 10k
        'transaction_date': DateTime(2026, 11, 12).millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Insert an expense from LAST month (should NOT be counted in November budget)
      await db.insert('transactions', {
        'id': 'tx_old',
        'user_id': userId,
        'account_id': 'acc_1',
        'type': 'expense',
        'title': 'October Expense',
        'amount_minor': 1500000,
        'transaction_date': DateTime(2026, 10, 25).millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      final budget = await budgetRepo.getBudgetForMonth(userId, year, month);

      expect(budget, isNotNull);
      expect(budget!.totalLimitMinor, 5000000); // 50k
      expect(budget.spentMinor, 3000000); // 20k + 10k = 30k
      expect(budget.remainingMinor, 2000000); // 50k - 30k = 20k
      expect(budget.utilizationPercentage, 60.0);
      expect(budget.isOverBudget, isFalse);
    });

    test('Detects warning and over-budget states', () async {
      await budgetRepo.setMonthlyBudget(
        userId: userId,
        name: 'Tight Budget',
        year: 2026,
        month: 11,
        totalLimitMinor: 1000000, // 10,000 PKR
        notificationThresholdPercent: 75,
      );

      // Spend 8,000 PKR (80% -> above 75% warning threshold)
      await db.insert('transactions', {
        'id': 'tx_warn',
        'user_id': userId,
        'account_id': 'acc_1',
        'type': 'expense',
        'title': 'Shopping',
        'amount_minor': 800000,
        'transaction_date': DateTime(2026, 11, 5).millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      var budget = await budgetRepo.getBudgetForMonth(userId, 2026, 11);
      expect(budget!.isWarning, isTrue);
      expect(budget.isOverBudget, isFalse);

      // Spend another 3,000 PKR -> total 11,000 PKR (> 10,000 limit)
      await db.insert('transactions', {
        'id': 'tx_over',
        'user_id': userId,
        'account_id': 'acc_1',
        'type': 'expense',
        'title': 'Shopping More',
        'amount_minor': 300000,
        'transaction_date': DateTime(2026, 11, 6).millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      budget = await budgetRepo.getBudgetForMonth(userId, 2026, 11);
      expect(budget!.isOverBudget, isTrue);
    });
  });
}

class _TestDatabaseService extends DatabaseService {
  _TestDatabaseService(this.testDb);
  final Database testDb;

  @override
  Database getActiveDatabase(String profileId) => testDb;

  @override
  bool isProfileDatabaseOpen(String profileId) => true;
}

