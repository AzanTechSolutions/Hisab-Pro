import 'dart:io';

import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Provides RFC 4180 compliant CSV exports for offline ledger records.
class ExportService {
  const ExportService();

  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

  /// Generates a CSV file containing the list of [transactions].
  Future<File> exportTransactionsToCsv({
    required List<FinancialTransaction> transactions,
    required Map<String, String> accountNames,
    required Map<String, String> categoryNames,
    String? targetDirectoryPath,
  }) async {
    final List<List<String>> rows = [
      [
        'ID',
        'Date & Time',
        'Type',
        'Title',
        'Amount',
        'Account',
        'Category',
        'Payment Method',
        'Status',
        'Notes',
      ],
    ];

    for (final tx in transactions) {
      final formattedDate = _dateFormatter.format(
        DateTime.fromMillisecondsSinceEpoch(tx.transactionDate),
      );
      final accountName = accountNames[tx.accountId] ?? tx.accountName ?? tx.accountId;
      final categoryName = tx.categoryId != null
          ? (categoryNames[tx.categoryId] ?? tx.categoryName ?? tx.categoryId!)
          : 'Uncategorized';
      final formattedAmount = (tx.amountMinor / 100.0).toStringAsFixed(2);

      rows.add([
        tx.id,
        formattedDate,
        tx.type.toUpperCase(),
        tx.title,
        formattedAmount,
        accountName,
        categoryName,
        tx.paymentMethod ?? 'N/A',
        tx.status,
        tx.notes ?? '',
      ]);
    }

    final csvContent = _encodeCsv(rows);
    return _saveCsvFile(
      prefix: 'transactions_ledger',
      csvContent: csvContent,
      targetDirectoryPath: targetDirectoryPath,
    );
  }

  /// Generates a CSV file containing all [loans] and debt balances.
  Future<File> exportLoansToCsv({
    required List<Loan> loans,
    required Map<String, String> peopleNames,
    String? targetDirectoryPath,
  }) async {
    final List<List<String>> rows = [
      [
        'ID',
        'Person',
        'Type',
        'Principal Amount',
        'Total Repaid',
        'Remaining Balance',
        'Status',
        'Loan Date',
        'Due Date',
        'Interest Rate (%)',
        'Notes',
      ],
    ];

    for (final loan in loans) {
      final personName = peopleNames[loan.personId] ?? loan.personName ?? loan.personId;
      final loanDateStr = DateFormat('yyyy-MM-dd').format(
        DateTime.fromMillisecondsSinceEpoch(loan.loanDate),
      );
      final dueDateStr = loan.dueDate != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(loan.dueDate!))
          : 'None';

      rows.add([
        loan.id,
        personName,
        loan.loanType.toUpperCase(),
        (loan.amountMinor / 100.0).toStringAsFixed(2),
        (loan.totalRepaidMinor / 100.0).toStringAsFixed(2),
        (loan.remainingBalanceMinor / 100.0).toStringAsFixed(2),
        loan.status.toUpperCase(),
        loanDateStr,
        dueDateStr,
        loan.interestRatePercent.toStringAsFixed(2),
        loan.notes ?? '',
      ]);
    }

    final csvContent = _encodeCsv(rows);
    return _saveCsvFile(
      prefix: 'loans_ledger',
      csvContent: csvContent,
      targetDirectoryPath: targetDirectoryPath,
    );
  }

  /// Generates a CSV file containing active [accounts] and balances.
  Future<File> exportAccountsToCsv({
    required List<Account> accounts,
    String? targetDirectoryPath,
  }) async {
    final List<List<String>> rows = [
      [
        'ID',
        'Account Name',
        'Type',
        'Currency',
        'Opening Balance',
        'Current Balance',
        'Status',
        'Notes',
      ],
    ];

    for (final acc in accounts) {
      rows.add([
        acc.id,
        acc.name,
        acc.accountType.toUpperCase(),
        acc.currency,
        (acc.openingBalanceMinor / 100.0).toStringAsFixed(2),
        (acc.currentBalanceMinor / 100.0).toStringAsFixed(2),
        acc.isArchived ? 'ARCHIVED' : 'ACTIVE',
        acc.notes ?? '',
      ]);
    }

    final csvContent = _encodeCsv(rows);
    return _saveCsvFile(
      prefix: 'accounts_summary',
      csvContent: csvContent,
      targetDirectoryPath: targetDirectoryPath,
    );
  }

  /// Generates a CSV file of the [FinancialSummaryReport].
  Future<File> exportFinancialSummaryToCsv({
    required FinancialSummaryReport summary,
    String? targetDirectoryPath,
  }) async {
    final List<List<String>> rows = [
      ['Metric', 'Amount / Value'],
      ['Total Income', (summary.totalIncomeMinor / 100.0).toStringAsFixed(2)],
      ['Total Expenses', (summary.totalExpenseMinor / 100.0).toStringAsFixed(2)],
      ['Net Savings', (summary.netSavingsMinor / 100.0).toStringAsFixed(2)],
      ['Savings Rate (%)', '${summary.savingsRatePercent.toStringAsFixed(1)}%'],
      ['Total Loans Given (Principal)', (summary.totalLentMinor / 100.0).toStringAsFixed(2)],
      ['Total Loans Taken (Principal)', (summary.totalBorrowedMinor / 100.0).toStringAsFixed(2)],
      ['Period Start', DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(summary.startDate))],
      ['Period End', DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(summary.endDate))],
    ];

    final csvContent = _encodeCsv(rows);
    return _saveCsvFile(
      prefix: 'financial_summary_report',
      csvContent: csvContent,
      targetDirectoryPath: targetDirectoryPath,
    );
  }

  /// Formats 2D list of cells into RFC 4180 compliant CSV string.
  String _encodeCsv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final formattedRow = row.map((cell) {
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n') || cell.contains('\r')) {
          final escaped = cell.replaceAll('"', '""');
          return '"$escaped"';
        }
        return cell;
      }).join(',');
      buffer.writeln(formattedRow);
    }
    return buffer.toString();
  }

  Future<File> _saveCsvFile({
    required String prefix,
    required String csvContent,
    String? targetDirectoryPath,
  }) async {
    String dir = targetDirectoryPath ?? '';
    if (dir.isEmpty) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        dir = docDir.path;
      } catch (_) {
        dir = Directory.current.path;
      }
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final filePath = '$dir/${prefix}_$timestamp.csv';
    final file = File(filePath);
    await file.writeAsString(csvContent, flush: true);
    AppLogger.info('CSV export generated at: $filePath');
    return file;
  }
}
