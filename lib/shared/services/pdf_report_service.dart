import 'dart:io';
import 'dart:typed_data';

import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/features/user_profiles/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates professional, publication-quality offline PDF financial statements.
class PdfReportService {
  const PdfReportService();

  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  /// Creates a multi-page PDF document and returns the raw bytes.
  Future<Uint8List> generateFinancialReportPdf({
    required UserProfile profile,
    required FinancialSummaryReport report,
    required List<Account> accounts,
    required List<FinancialTransaction> transactions,
    required List<Loan> loans,
    String currencySymbol = 'Rs. ',
  }) async {
    final pdf = pw.Document(
      title: 'Hisab Pro - Financial Statement (${profile.fullName})',
      author: 'AzanTech Solutions',
    );

    final generatedAt = _dateTimeFormat.format(DateTime.now());
    final primaryColor = PdfColor.fromHex('#0F172A'); // Deep Navy
    final emeraldColor = PdfColor.fromHex('#10B981'); // Emerald
    final dangerColor = PdfColor.fromHex('#EF4444'); // Danger
    final subtleGray = PdfColor.fromHex('#F1F5F9'); // Light gray

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(context, profile, generatedAt, primaryColor, emeraldColor),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Executive Summary Grid
          _buildExecutiveSummary(report, currencySymbol, primaryColor, emeraldColor, dangerColor, subtleGray),
          pw.SizedBox(height: 18),

          // 2. Accounts Balance Table
          if (accounts.isNotEmpty) ...[
            _buildSectionTitle('Active Accounts Summary', primaryColor),
            pw.SizedBox(height: 6),
            _buildAccountsTable(accounts, currencySymbol, subtleGray),
            pw.SizedBox(height: 18),
          ],

          // 3. Category Expense Breakdown
          if (report.categoryBreakdown.isNotEmpty) ...[
            _buildSectionTitle('Expense Breakdown by Category', primaryColor),
            pw.SizedBox(height: 6),
            _buildCategoryTable(report.categoryBreakdown, currencySymbol, subtleGray),
            pw.SizedBox(height: 18),
          ],

          // 4. Monthly Trend (if available)
          if (report.cashFlowTrend.isNotEmpty) ...[
            _buildSectionTitle('Recent Cash Flow Trend', primaryColor),
            pw.SizedBox(height: 6),
            _buildCashFlowTable(report.cashFlowTrend, currencySymbol, subtleGray, emeraldColor, dangerColor),
            pw.SizedBox(height: 18),
          ],

          // 5. Loans / Debt Ledger (if available)
          if (loans.isNotEmpty) ...[
            _buildSectionTitle('Loans & Debt Ledger', primaryColor),
            pw.SizedBox(height: 6),
            _buildLoansTable(loans, currencySymbol, subtleGray, emeraldColor, dangerColor),
            pw.SizedBox(height: 18),
          ],

          // 6. Detailed Transactions Ledger
          if (transactions.isNotEmpty) ...[
            _buildSectionTitle('Recent Transactions Ledger', primaryColor),
            pw.SizedBox(height: 6),
            _buildTransactionsTable(transactions, currencySymbol, subtleGray, emeraldColor, dangerColor),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    pw.Context context,
    UserProfile profile,
    String generatedAt,
    PdfColor primaryColor,
    PdfColor emeraldColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    decoration: pw.BoxDecoration(
                      color: emeraldColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'H',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'HISAB PRO',
                    style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 18, letterSpacing: 1),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Financial Statement & Analytics',
                style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                profile.fullName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: primaryColor),
              ),
              pw.Text(
                'Generated: $generatedAt',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
              ),
              pw.Text(
                'AzanTech Solutions | +92 329 5892004',
                style: pw.TextStyle(color: emeraldColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '100% Offline Ledger | Developed by AzanTech Solutions (https://azantechsolutions.pages.dev)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: color,
        fontWeight: pw.FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(
    FinancialSummaryReport report,
    String symbol,
    PdfColor primaryColor,
    PdfColor emeraldColor,
    PdfColor dangerColor,
    PdfColor subtleGray,
  ) {
    final income = (report.totalIncomeMinor / 100.0).toStringAsFixed(0);
    final expense = (report.totalExpenseMinor / 100.0).toStringAsFixed(0);
    final net = (report.netSavingsMinor / 100.0).toStringAsFixed(0);
    final rate = report.savingsRatePercent.toStringAsFixed(1);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: subtleGray,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryBox('Total Income', '$symbol$income', emeraldColor),
          _summaryBox('Total Expenses', '$symbol$expense', dangerColor),
          _summaryBox('Net Savings', '$symbol$net', primaryColor),
          _summaryBox('Savings Rate', '$rate%', emeraldColor),
        ],
      ),
    );
  }

  pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  pw.Widget _buildAccountsTable(List<Account> accounts, String symbol, PdfColor subtleGray) {
    return pw.TableHelper.fromTextArray(
      headers: ['Account Name', 'Type', 'Current Balance'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      data: accounts.map((acc) {
        final bal = (acc.currentBalanceMinor / 100.0).toStringAsFixed(0);
        return [
          acc.name,
          acc.accountType.toUpperCase(),
          '$symbol$bal',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildCategoryTable(List<CategorySpendingSlice> slices, String symbol, PdfColor subtleGray) {
    return pw.TableHelper.fromTextArray(
      headers: ['Category', 'Total Spent', 'Percentage of Expenses'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      data: slices.map((s) {
        final amt = (s.amountMinor / 100.0).toStringAsFixed(0);
        return [
          s.categoryName,
          '$symbol$amt',
          '${s.percentage.toStringAsFixed(1)}%',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildCashFlowTable(
    List<MonthlyCashFlowPoint> trend,
    String symbol,
    PdfColor subtleGray,
    PdfColor emeraldColor,
    PdfColor dangerColor,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Month', 'Total Income', 'Total Expense', 'Net Cash Flow'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      data: trend.map((t) {
        final inc = (t.incomeMinor / 100.0).toStringAsFixed(0);
        final exp = (t.expenseMinor / 100.0).toStringAsFixed(0);
        final net = ((t.incomeMinor - t.expenseMinor) / 100.0).toStringAsFixed(0);
        return [
          t.monthLabel,
          '$symbol$inc',
          '$symbol$exp',
          '$symbol$net',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildLoansTable(
    List<Loan> loans,
    String symbol,
    PdfColor subtleGray,
    PdfColor emeraldColor,
    PdfColor dangerColor,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Contact', 'Type', 'Principal', 'Repaid', 'Remaining', 'Status'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      data: loans.map((l) {
        final principal = (l.amountMinor / 100.0).toStringAsFixed(0);
        final repaid = (l.totalRepaidMinor / 100.0).toStringAsFixed(0);
        final remaining = (l.remainingBalanceMinor / 100.0).toStringAsFixed(0);
        final status = l.isPaid ? 'Settled' : (l.isOverdue ? 'Overdue' : 'Active');
        return [
          l.personName ?? 'Contact',
          l.isGiven ? 'Lent' : 'Borrowed',
          '$symbol$principal',
          '$symbol$repaid',
          '$symbol$remaining',
          status,
        ];
      }).toList(),
    );
  }

  pw.Widget _buildTransactionsTable(
    List<FinancialTransaction> txs,
    String symbol,
    PdfColor subtleGray,
    PdfColor emeraldColor,
    PdfColor dangerColor,
  ) {
    // Show up to 50 most recent transactions for document cleanliness
    final displayTxs = txs.take(50).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Title', 'Type', 'Category', 'Account', 'Amount'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      data: displayTxs.map((tx) {
        final dt = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(tx.transactionDate));
        final amt = (tx.amountMinor / 100.0).toStringAsFixed(0);
        final isInc = tx.isIncome;
        return [
          dt,
          tx.title,
          tx.type.toUpperCase(),
          tx.categoryName ?? 'General',
          tx.accountName ?? 'Account',
          '${isInc ? '+' : '-'}$symbol$amt',
        ];
      }).toList(),
    );
  }

  /// Writes the PDF bytes to the specified folder or returns the file.
  Future<File> savePdfFile({
    required Uint8List pdfBytes,
    required String targetDirectoryPath,
    String prefix = 'hisab_financial_report',
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final filePath = '$targetDirectoryPath/${prefix}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes, flush: true);
    AppLogger.info('PDF report saved to: $filePath');
    return file;
  }
}
