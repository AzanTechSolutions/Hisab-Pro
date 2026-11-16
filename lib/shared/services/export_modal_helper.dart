import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/features/reports/reports_providers.dart';
import 'package:hisab_pro/features/settings/settings_providers.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/export_service.dart';
import 'package:hisab_pro/shared/services/pdf_report_service.dart';
import 'package:printing/printing.dart';

class ExportModalHelper {
  static const _pdfService = PdfReportService();
  static const _csvService = ExportService();

  /// Opens the Export Options Modal Bottom Sheet.
  static void showExportModal(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExportBottomSheet(
        ref: ref,
        isDark: isDark,
        isUrdu: settings.isUrdu,
        currencySymbol: settings.currencySymbol,
      ),
    );
  }
}

class _ExportBottomSheet extends StatefulWidget {
  const _ExportBottomSheet({
    required this.ref,
    required this.isDark,
    required this.isUrdu,
    required this.currencySymbol,
  });

  final WidgetRef ref;
  final bool isDark;
  final bool isUrdu;
  final String currencySymbol;

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  String _selectedFormat = 'pdf'; // 'pdf' or 'csv'
  bool _isExporting = false;
  String? _statusMessage;

  Future<void> _handleSaveToFolder() async {
    setState(() {
      _isExporting = true;
      _statusMessage = widget.isUrdu ? 'فولڈر کا انتخاب کریں...' : 'Selecting folder...';
    });

    try {
      // 1. Let the user choose their own target directory!
      final targetDir = await FilePicker.getDirectoryPath(
        dialogTitle: widget.isUrdu ? 'رپورٹ محفوظ کرنے کے لیے فولڈر منتخب کریں' : 'Select folder to save report',
      );

      if (targetDir == null) {
        // User cancelled folder picker
        setState(() {
          _isExporting = false;
          _statusMessage = null;
        });
        return;
      }

      setState(() {
        _statusMessage = widget.isUrdu ? 'فائل تیار ہو رہی ہے...' : 'Generating files...';
      });

      final profile = widget.ref.read(activeProfileProvider);
      if (profile == null) throw Exception('No active profile');

      final repo = widget.ref.read(reportsRepositoryProvider);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
      final report = await repo.generateReport(profile.id, startDate: start, endDate: end);

      if (_selectedFormat == 'pdf') {
        final accounts = await widget.ref.read(accountsListProvider.future);
        final transactions = await widget.ref.read(filteredTransactionsProvider.future);
        final loansGiven = await widget.ref.read(loansByTypeProvider('loan_given').future);
        final loansTaken = await widget.ref.read(loansByTypeProvider('loan_taken').future);
        final allLoans = [...loansGiven, ...loansTaken];

        final pdfBytes = await ExportModalHelper._pdfService.generateFinancialReportPdf(
          profile: profile,
          report: report,
          accounts: accounts,
          transactions: transactions,
          loans: allLoans,
          currencySymbol: widget.currencySymbol,
        );

        final savedFile = await ExportModalHelper._pdfService.savePdfFile(
          pdfBytes: pdfBytes,
          targetDirectoryPath: targetDir,
        );

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            context: context,
            title: widget.isUrdu ? 'پی ڈی ایف رپورٹ محفوظ ہو گئی' : 'PDF Report Saved',
            filePath: savedFile.path,
            isPdf: true,
          );
        }
      } else {
        // CSV Export
        final transactions = await widget.ref.read(filteredTransactionsProvider.future);
        final loansGiven = await widget.ref.read(loansByTypeProvider('loan_given').future);
        final loansTaken = await widget.ref.read(loansByTypeProvider('loan_taken').future);
        final accounts = await widget.ref.read(accountsListProvider.future);

        final txFile = await ExportModalHelper._csvService.exportTransactionsToCsv(
          transactions: transactions,
          accountNames: {for (final a in accounts) a.id: a.name},
          categoryNames: {},
          targetDirectoryPath: targetDir,
        );

        final loanFile = await ExportModalHelper._csvService.exportLoansToCsv(
          loans: [...loansGiven, ...loansTaken],
          peopleNames: {},
          targetDirectoryPath: targetDir,
        );

        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(
            context: context,
            title: widget.isUrdu ? 'سی ایس وی رپورٹس محفوظ ہو گئیں' : 'CSV Reports Saved',
            filePath: '${txFile.path}\n${loanFile.path}',
            isPdf: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _handleShareOrPreview() async {
    setState(() {
      _isExporting = true;
      _statusMessage = widget.isUrdu ? 'تیار ہو رہی ہے...' : 'Generating preview...';
    });

    try {
      final profile = widget.ref.read(activeProfileProvider);
      if (profile == null) throw Exception('No active profile');

      final repo = widget.ref.read(reportsRepositoryProvider);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
      final report = await repo.generateReport(profile.id, startDate: start, endDate: end);

      final accounts = await widget.ref.read(accountsListProvider.future);
      final transactions = await widget.ref.read(filteredTransactionsProvider.future);
      final loansGiven = await widget.ref.read(loansByTypeProvider('loan_given').future);
      final loansTaken = await widget.ref.read(loansByTypeProvider('loan_taken').future);
      final allLoans = [...loansGiven, ...loansTaken];

      final pdfBytes = await ExportModalHelper._pdfService.generateFinancialReportPdf(
        profile: profile,
        report: report,
        accounts: accounts,
        transactions: transactions,
        loans: allLoans,
        currencySymbol: widget.currencySymbol,
      );

      final filename = 'hisab_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (mounted) {
        Navigator.pop(context);
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  void _showSuccessDialog({
    required BuildContext context,
    required String title,
    required String filePath,
    required bool isPdf,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.emerald, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isUrdu ? 'فائل کامیابی سے منتخب کردہ فولڈر میں محفوظ ہو گئی ہے:' : 'File saved successfully to your selected location:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download_rounded, color: AppColors.emerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isUrdu ? 'رپورٹ برآمد کریں' : 'Export Financial Reports',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.isUrdu ? 'پی ڈی ایف یا سی ایس وی فارمیٹ منتخب کریں' : 'Choose format & select where to save',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Format Selection Chips
          Text(
            widget.isUrdu ? 'فارمیٹ منتخب کریں:' : 'Select Format:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _formatCard(
                  key: 'pdf',
                  icon: Icons.picture_as_pdf,
                  title: 'PDF Report',
                  subtitle: widget.isUrdu ? 'خوبصورت پرنٹ ایبل' : 'Printable & Branded',
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _formatCard(
                  key: 'csv',
                  icon: Icons.table_chart_outlined,
                  title: 'CSV Spreadsheets',
                  subtitle: widget.isUrdu ? 'ایکسل کے لیے' : 'Excel & Raw Data',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_statusMessage != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          // Action 1: Select Folder & Save
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isExporting ? null : _handleSaveToFolder,
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.folder_open),
              label: Text(
                widget.isUrdu ? 'فولڈر منتخب کر کے محفوظ کریں' : 'Select Folder & Save to Device',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action 2: Share / Open Directly (PDF only)
          if (_selectedFormat == 'pdf') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDark ? Colors.white : AppColors.textPrimary,
                  side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isExporting ? null : _handleShareOrPreview,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(
                  widget.isUrdu ? 'شیئر یا دیکھیں (Share / Open)' : 'Share or Open PDF Directly',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatCard({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedFormat == key;
    return InkWell(
      onTap: () => setState(() => _selectedFormat = key),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : (widget.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : (widget.isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? color : null)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
