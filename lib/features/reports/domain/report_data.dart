/// Report and chart data structures for financial analytics.
class FinancialSummaryReport {
  const FinancialSummaryReport({
    required this.startDate,
    required this.endDate,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netSavingsMinor,
    required this.savingsRatePercent,
    required this.totalLentMinor,
    required this.totalBorrowedMinor,
    this.cashFlowTrend = const [],
    this.categoryBreakdown = const [],
  });

  final int startDate;
  final int endDate;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netSavingsMinor;
  final double savingsRatePercent;
  final int totalLentMinor;
  final int totalBorrowedMinor;
  final List<MonthlyCashFlowPoint> cashFlowTrend;
  final List<CategorySpendingSlice> categoryBreakdown;
}

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final String monthLabel; // e.g. "Nov"
  final int year;
  final int month;
  final int incomeMinor;
  final int expenseMinor;

  int get netSavingsMinor => incomeMinor - expenseMinor;
}

class CategorySpendingSlice {
  const CategorySpendingSlice({
    required this.categoryName,
    required this.colorHex,
    this.iconKey,
    required this.amountMinor,
    required this.percentage,
  });

  final String categoryName;
  final String colorHex;
  final String? iconKey;
  final int amountMinor;
  final double percentage; // e.g. 24.5
}

