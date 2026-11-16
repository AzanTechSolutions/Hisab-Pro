import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:intl/intl.dart';

/// Repository for aggregating financial reports and chart datasets.
class ReportsRepository {
  ReportsRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;

  /// Compiles a comprehensive financial report for [userId] within [startDate] and [endDate].
  Future<FinancialSummaryReport> generateReport(
    String userId, {
    required int startDate,
    required int endDate,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    // 1. Total Income & Expense in date range
    final totalsResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_minor ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_minor ELSE 0 END), 0) AS total_expense
      FROM transactions
      WHERE user_id = ? AND status = 'posted'
        AND transaction_date >= ? AND transaction_date <= ?
      ''',
      [userId, startDate, endDate],
    );

    final totalIncome = (totalsResult.first['total_income'] as int?) ?? 0;
    final totalExpense = (totalsResult.first['total_expense'] as int?) ?? 0;
    final netSavings = totalIncome - totalExpense;
    final savingsRate = (totalIncome > 0)
        ? ((netSavings > 0 ? netSavings : 0) / totalIncome) * 100.0
        : 0.0;

    // 2. Active Loans Exposure
    final loansResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(CASE WHEN loan_type = 'loan_given' THEN amount_minor ELSE 0 END), 0) AS total_lent,
        COALESCE(SUM(CASE WHEN loan_type = 'loan_taken' THEN amount_minor ELSE 0 END), 0) AS total_borrowed
      FROM loans
      WHERE user_id = ? AND status != 'paid' AND status != 'closed'
      ''',
      [userId],
    );
    final totalLent = (loansResult.first['total_lent'] as int?) ?? 0;
    final totalBorrowed = (loansResult.first['total_borrowed'] as int?) ?? 0;

    // 3. Category Breakdown (for Pie Chart)
    final categoryRows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.color_hex, '#10B981') AS color_hex,
        c.icon_key,
        SUM(t.amount_minor) AS category_total
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ? AND t.type = 'expense' AND t.status = 'posted'
        AND t.transaction_date >= ? AND t.transaction_date <= ?
      GROUP BY t.category_id
      ORDER BY category_total DESC
      ''',
      [userId, startDate, endDate],
    );

    final List<CategorySpendingSlice> categorySlices = [];
    final fallbackColors = [
      '#EF4444', '#F97316', '#F59E0B', '#10B981', '#06B6D4',
      '#3B82F6', '#6366F1', '#8B5CF6', '#EC4899', '#64748B'
    ];

    for (var i = 0; i < categoryRows.length; i++) {
      final row = categoryRows[i];
      final amount = (row['category_total'] as int?) ?? 0;
      final percentage = (totalExpense > 0) ? (amount / totalExpense) * 100.0 : 0.0;
      final assignedColor = (row['color_hex'] as String?).let((c) => c != null && c.startsWith('#') ? c : fallbackColors[i % fallbackColors.length]);

      categorySlices.add(
        CategorySpendingSlice(
          categoryName: row['category_name'] as String,
          colorHex: assignedColor,
          iconKey: row['icon_key'] as String?,
          amountMinor: amount,
          percentage: percentage,
        ),
      );
    }

    // 4. Monthly Cash Flow Trend (Last 6 Months for Bar Chart)
    final now = DateTime.now();
    final List<MonthlyCashFlowPoint> trendPoints = [];

    for (var i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthStart = targetDate.millisecondsSinceEpoch;
      final monthEnd = (targetDate.month == 12)
          ? DateTime(targetDate.year + 1, 1, 1).millisecondsSinceEpoch - 1
          : DateTime(targetDate.year, targetDate.month + 1, 1).millisecondsSinceEpoch - 1;

      final mResult = await db.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount_minor ELSE 0 END), 0) AS m_income,
          COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_minor ELSE 0 END), 0) AS m_expense
        FROM transactions
        WHERE user_id = ? AND status = 'posted'
          AND transaction_date >= ? AND transaction_date <= ?
        ''',
        [userId, monthStart, monthEnd],
      );

      final mIncome = (mResult.first['m_income'] as int?) ?? 0;
      final mExpense = (mResult.first['m_expense'] as int?) ?? 0;
      final label = DateFormat('MMM').format(targetDate);

      trendPoints.add(
        MonthlyCashFlowPoint(
          monthLabel: label,
          year: targetDate.year,
          month: targetDate.month,
          incomeMinor: mIncome,
          expenseMinor: mExpense,
        ),
      );
    }

    AppLogger.info('Generated report for user $userId ($startDate -> $endDate)');

    return FinancialSummaryReport(
      startDate: startDate,
      endDate: endDate,
      totalIncomeMinor: totalIncome,
      totalExpenseMinor: totalExpense,
      netSavingsMinor: netSavings,
      savingsRatePercent: savingsRate,
      totalLentMinor: totalLent,
      totalBorrowedMinor: totalBorrowed,
      cashFlowTrend: trendPoints,
      categoryBreakdown: categorySlices,
    );
  }
}

extension<T> on T? {
  R let<R>(R Function(T) op) => this != null ? op(this as T) : (null as R);
}

