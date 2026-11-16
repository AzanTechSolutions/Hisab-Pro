import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/features/reports/data/reports_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 5: Reports & Analytics Aggregation Engine', () {
    late Database db;
    late DatabaseService dbService;
    late ReportsRepository reportsRepo;
    const userId = 'test_user_p5_reports';

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

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

      await db.execute('''
        CREATE TABLE loans (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          person_id TEXT NOT NULL,
          loan_type TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          interest_rate_percent REAL NOT NULL DEFAULT 0,
          loan_date INTEGER NOT NULL,
          due_date INTEGER,
          description TEXT,
          notes TEXT,
          account_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      dbService = _TestDatabaseService(db);
      reportsRepo = ReportsRepository(databaseService: dbService);
    });

    tearDown(() async {
      await db.close();
    });

    test('Generates accurate totals, savings rate, and category pie slices', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

      // Seed categories
      await db.insert('categories', {
        'id': 'cat_food',
        'user_id': userId,
        'name': 'Food',
        'type': 'expense',
        'color_hex': '#EF4444',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      await db.insert('categories', {
        'id': 'cat_rent',
        'user_id': userId,
        'name': 'Rent',
        'type': 'expense',
        'color_hex': '#3B82F6',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Income: 100,000 PKR
      await db.insert('transactions', {
        'id': 'tx_inc',
        'user_id': userId,
        'account_id': 'acc_1',
        'type': 'income',
        'title': 'Salary',
        'amount_minor': 10000000, // 100k
        'transaction_date': now.millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Expense 1: Food 20,000 PKR
      await db.insert('transactions', {
        'id': 'tx_exp1',
        'user_id': userId,
        'account_id': 'acc_1',
        'category_id': 'cat_food',
        'type': 'expense',
        'title': 'Dinner',
        'amount_minor': 2000000, // 20k
        'transaction_date': now.millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Expense 2: Rent 30,000 PKR
      await db.insert('transactions', {
        'id': 'tx_exp2',
        'user_id': userId,
        'account_id': 'acc_1',
        'category_id': 'cat_rent',
        'type': 'expense',
        'title': 'House Rent',
        'amount_minor': 3000000, // 30k
        'transaction_date': now.millisecondsSinceEpoch,
        'status': 'posted',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      final report = await reportsRepo.generateReport(userId, startDate: start, endDate: end);

      expect(report.totalIncomeMinor, 10000000); // 100k
      expect(report.totalExpenseMinor, 5000000); // 20k + 30k = 50k
      expect(report.netSavingsMinor, 5000000); // 100k - 50k = 50k
      expect(report.savingsRatePercent, 50.0); // 50%

      // Category pie slices: Rent (60%) and Food (40%)
      expect(report.categoryBreakdown.length, 2);
      expect(report.categoryBreakdown.first.categoryName, 'Rent');
      expect(report.categoryBreakdown.first.percentage, 60.0);
      expect(report.categoryBreakdown[1].categoryName, 'Food');
      expect(report.categoryBreakdown[1].percentage, 40.0);

      // Monthly cash flow trend points (6 months)
      expect(report.cashFlowTrend.length, 6);
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

