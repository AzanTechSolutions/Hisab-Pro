import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/features/user_profiles/user_profile.dart';
import 'package:hisab_pro/shared/services/pdf_report_service.dart';

void main() {
  group('PdfReportService Tests', () {
    const pdfService = PdfReportService();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hisab_pdf_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates valid non-empty PDF document bytes with all report sections', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final profile = UserProfile(
        id: 'p_test',
        username: 'test_user',
        fullName: 'Test User',
        createdAt: now,
        updatedAt: now,
        biometricEnabled: false,
      );

      final report = FinancialSummaryReport(
        startDate: DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        endDate: now,
        totalIncomeMinor: 5000000,
        totalExpenseMinor: 2000000,
        netSavingsMinor: 3000000,
        savingsRatePercent: 60.0,
        totalLentMinor: 1000000,
        totalBorrowedMinor: 0,
        cashFlowTrend: const [
          MonthlyCashFlowPoint(monthLabel: 'Oct', year: 2026, month: 10, incomeMinor: 5000000, expenseMinor: 2000000),
          MonthlyCashFlowPoint(monthLabel: 'Nov', year: 2026, month: 11, incomeMinor: 6000000, expenseMinor: 1500000),
        ],
        categoryBreakdown: const [
          CategorySpendingSlice(categoryName: 'Salary', colorHex: '#10B981', amountMinor: 2000000, percentage: 100.0),
        ],
      );

      final accounts = [
        Account(
          id: 'acc_1',
          userId: 'p_test',
          name: 'Main Cash',
          accountType: 'cash',
          currency: 'PKR',
          currentBalanceMinor: 3000000,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final transactions = [
        FinancialTransaction(
          id: 'tx_1',
          userId: 'p_test',
          accountId: 'acc_1',
          type: 'income',
          title: 'Monthly Salary',
          amountMinor: 5000000,
          transactionDate: now,
          status: 'posted',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final loans = [
        Loan(
          id: 'loan_1',
          userId: 'p_test',
          personId: 'per_1',
          accountId: 'acc_1',
          loanType: 'loan_given',
          amountMinor: 1000000,
          totalRepaidMinor: 200000,
          loanDate: now,
          status: 'active',
          personName: 'Ahmed Ali',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final pdfBytes = await pdfService.generateFinancialReportPdf(
        profile: profile,
        report: report,
        accounts: accounts,
        transactions: transactions,
        loans: loans,
        currencySymbol: 'Rs. ',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF header signature: %PDF-
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), equals('%PDF'));

      // Test saving to custom directory
      final savedFile = await pdfService.savePdfFile(
        pdfBytes: pdfBytes,
        targetDirectoryPath: tempDir.path,
      );

      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.lengthSync(), equals(pdfBytes.length));
    });
  });
}
