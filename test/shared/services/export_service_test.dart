import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/shared/services/export_service.dart';

void main() {
  group('Phase 6: Offline CSV Export Service Tests', () {
    const exportService = ExportService();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hisab_export_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Exports transactions to RFC 4180 compliant CSV file', () async {
      final now = DateTime.now();
      final transactions = [
        FinancialTransaction(
          id: 'tx_1',
          userId: 'u1',
          accountId: 'acc_1',
          categoryId: 'cat_1',
          type: 'expense',
          title: 'Grocery, "Special" Items & Milk', // contains comma and quotes
          amountMinor: 250050, // Rs. 2500.50
          transactionDate: now.millisecondsSinceEpoch,
          status: 'posted',
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          notes: 'Line 1\nLine 2', // contains newline
        ),
      ];

      final file = await exportService.exportTransactionsToCsv(
        transactions: transactions,
        accountNames: {'acc_1': 'Meezan Bank'},
        categoryNames: {'cat_1': 'Food'},
        targetDirectoryPath: tempDir.path,
      );

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Check header
      expect(content.contains('ID,Date & Time,Type,Title,Amount,Account,Category'), isTrue);
      // Check RFC 4180 escaped title
      expect(content.contains('"Grocery, ""Special"" Items & Milk"'), isTrue);
      // Check formatted amount
      expect(content.contains('2500.50'), isTrue);
      // Check account & category
      expect(content.contains('Meezan Bank'), isTrue);
      expect(content.contains('Food'), isTrue);
    });

    test('Exports loans ledger to CSV file', () async {
      final now = DateTime.now();
      final loans = [
        Loan(
          id: 'loan_1',
          userId: 'u1',
          personId: 'p_1',
          loanType: 'loan_given',
          accountId: 'acc_1',
          amountMinor: 5000000, // Rs. 50,000.00
          totalRepaidMinor: 2000000, // Rs. 20,000.00
          interestRatePercent: 0,
          loanDate: now.millisecondsSinceEpoch,
          status: 'active',
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final file = await exportService.exportLoansToCsv(
        loans: loans,
        peopleNames: {'p_1': 'Ali Ahmed'},
        targetDirectoryPath: tempDir.path,
      );

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Ali Ahmed'), isTrue);
      expect(content.contains('50000.00'), isTrue);
      expect(content.contains('20000.00'), isTrue);
      expect(content.contains('30000.00'), isTrue);
      expect(content.contains('ACTIVE'), isTrue);
    });

    test('Exports accounts summary to CSV file', () async {
      final now = DateTime.now();
      final accounts = [
        Account(
          id: 'acc_1',
          userId: 'u1',
          name: 'Cash In Hand',
          accountType: 'cash',
          currency: 'PKR',
          openingBalanceMinor: 1000000,
          currentBalanceMinor: 1250000,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final file = await exportService.exportAccountsToCsv(
        accounts: accounts,
        targetDirectoryPath: tempDir.path,
      );

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Cash In Hand'), isTrue);
      expect(content.contains('CASH'), isTrue);
      expect(content.contains('10000.00'), isTrue);
      expect(content.contains('12500.00'), isTrue);
      expect(content.contains('ACTIVE'), isTrue);
    });

    test('Exports financial summary report to CSV file', () async {
      final now = DateTime.now();
      final summary = FinancialSummaryReport(
        totalIncomeMinor: 10000000,
        totalExpenseMinor: 6000000,
        netSavingsMinor: 4000000,
        savingsRatePercent: 40.0,
        totalLentMinor: 1500000,
        totalBorrowedMinor: 500000,
        startDate: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        endDate: now.millisecondsSinceEpoch,
      );

      final file = await exportService.exportFinancialSummaryToCsv(
        summary: summary,
        targetDirectoryPath: tempDir.path,
      );

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Total Income,100000.00'), isTrue);
      expect(content.contains('Total Expenses,60000.00'), isTrue);
      expect(content.contains('Net Savings,40000.00'), isTrue);
      expect(content.contains('Savings Rate (%),40.0%'), isTrue);
    });
  });
}
