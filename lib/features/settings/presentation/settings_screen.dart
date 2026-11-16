import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/features/reports/reports_providers.dart';
import 'package:hisab_pro/features/settings/domain/app_settings_state.dart';
import 'package:hisab_pro/features/settings/settings_providers.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/export_modal_helper.dart';
import 'package:hisab_pro/shared/services/export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<Map<String, String>> _availableCurrencies = [
    {'code': 'PKR', 'symbol': 'Rs.', 'name': 'Pakistani Rupee (PKR)'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar (USD)'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro (EUR)'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound (GBP)'},
    {'code': 'AED', 'symbol': 'AED', 'name': 'UAE Dirham (AED)'},
    {'code': 'SAR', 'symbol': 'SAR', 'name': 'Saudi Riyal (SAR)'},
  ];

  Future<void> _handleExportCsv(BuildContext context, WidgetRef ref) async {
    try {
      const exportService = ExportService();
      final transactionsAsync = ref.read(filteredTransactionsProvider);
      final accountsAsync = ref.read(accountsListProvider);
      final loansAsync = ref.read(loansByTypeProvider(null));
      final summaryAsync = ref.read(activeReportProvider);

      final accounts = accountsAsync.asData?.value ?? [];
      final transactions = transactionsAsync.asData?.value ?? [];
      final loans = loansAsync.asData?.value ?? [];
      final summary = summaryAsync.asData?.value;

      final accountNames = {for (final a in accounts) a.id: a.name};

      final txFile = await exportService.exportTransactionsToCsv(
        transactions: transactions,
        accountNames: accountNames,
        categoryNames: {},
      );

      final loansFile = await exportService.exportLoansToCsv(
        loans: loans,
        peopleNames: {},
      );

      if (summary != null) {
        await exportService.exportFinancialSummaryToCsv(summary: summary);
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('CSV Reports Exported'),
            content: Text(
              'Your offline CSV files have been generated successfully:\n\n'
              '• Transactions: ${txFile.path}\n'
              '• Loans: ${loansFile.path}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final activeProfile = ref.watch(activeProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.isUrdu ? 'ترتیبات و ترجیحات' : 'Settings & Preferences'),
      ),
      body: Directionality(
        textDirection: settings.isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Active Profile Info Card
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: AppColors.emerald, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeProfile?.fullName ?? (settings.isUrdu ? 'صارف' : 'Active User'),
                            style: AppTextStyles.title,
                          ),
                          Text(
                            settings.isUrdu ? 'فعال پروفائل • آف لائن محفوظ' : 'Active Profile • Encrypted',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/profiles'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(settings.isUrdu ? 'تبدیل کریں' : 'Switch'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Financial & Currency
            _buildSectionHeader(settings.isUrdu ? 'کرنسی اور حساب کتاب' : 'Currency & Accounts'),
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.monetization_on_outlined, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'ڈیفالٹ کرنسی' : 'Default Currency'),
                    subtitle: Text('${settings.currencyCode} (${settings.currencySymbol})'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showCurrencyPicker(context, settings, settingsNotifier),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'رپورٹس برآمد کریں (PDF / CSV)' : 'Export Financial Reports'),
                    subtitle: Text(settings.isUrdu ? 'پی ڈی ایف یا سی ایس وی اپنی مرضی کے فولڈر میں' : 'Export PDF or CSV to your chosen folder'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => ExportModalHelper.showExportModal(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Localization & Language
            _buildSectionHeader(settings.isUrdu ? 'زبان اور انٹرفیس' : 'Language & Display'),
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'ایپ کی زبان' : 'Application Language'),
                    subtitle: Text(settings.isUrdu ? 'اردو (Urdu RTL)' : 'English (LTR)'),
                    trailing: DropdownButton<String>(
                      value: settings.locale.languageCode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ur', child: Text('اردو (Urdu)')),
                      ],
                      onChanged: (lang) {
                        if (lang != null) settingsNotifier.setLanguage(lang);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'تھیم موڈ' : 'Theme Mode'),
                    subtitle: Text(_themeModeName(settings.themeMode, settings.isUrdu)),
                    trailing: DropdownButton<ThemeMode>(
                      value: settings.themeMode,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(settings.isUrdu ? 'سسٹم' : 'System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(settings.isUrdu ? 'روشن' : 'Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(settings.isUrdu ? 'تاریک' : 'Dark'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) settingsNotifier.setThemeMode(mode);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Security & Backup
            _buildSectionHeader(settings.isUrdu ? 'سیکیورٹی اور بیک اپ' : 'Security & Backup'),
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'بائیو میٹرک انلاک' : 'Biometric Authentication'),
                    subtitle: Text(settings.isUrdu ? 'فنگر پرنٹ یا فیس انلاک' : 'Fingerprint / Face ID unlock'),
                    value: settings.isBiometricEnabled,
                    onChanged: settingsNotifier.setBiometricEnabled,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_clock, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'خودکار لاک کا وقت' : 'Auto-Lock Inactivity'),
                    subtitle: Text(
                      settings.autoLockMinutes == 0
                          ? (settings.isUrdu ? 'فوری' : 'Immediately')
                          : '${settings.autoLockMinutes} ${settings.isUrdu ? "منٹ" : "Minutes"}',
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.autoLockMinutes,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Immediately')),
                        DropdownMenuItem(value: 1, child: Text('1 Minute')),
                        DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                      ],
                      onChanged: (val) {
                        if (val != null) settingsNotifier.setAutoLockMinutes(val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'خفیہ کردہ بیک اپ اور بحالی' : 'Encrypted Backup & Restore'),
                    subtitle: Text(settings.isUrdu ? 'آf لائن .hisab فائل بنائیں یا بحال کریں' : 'Export / Restore .hisab archive'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/backup'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_edu, color: AppColors.emerald),
                    title: Text(settings.isUrdu ? 'آڈٹ ٹریل اور ایونٹ لاگ' : 'Audit Trail & Event Log'),
                    subtitle: Text(settings.isUrdu ? 'سیکیورٹی اور ٹرانزیکشن ہسٹری لاگ' : 'View financial & security event history'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/audit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Developer Company Branding
            _buildSectionHeader(settings.isUrdu ? 'ڈویلپر کی معلومات' : 'Developer & Company'),
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/azantech_logo.png',
                            width: 52,
                            height: 52,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.business, color: AppColors.emerald, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.isUrdu ? 'ڈویلپڈ بائے اذان ٹیک سلوشنز' : 'Developed by AzanTech Solutions',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                settings.isUrdu ? 'جدید، محفوظ اور آف لائن حل' : 'Enterprise & Offline-First Solutions',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 18, color: AppColors.emerald),
                        const SizedBox(width: 8),
                        Text(
                          settings.isUrdu ? 'رابطہ: ' : 'Contact: ',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const Text(
                          '+92 329 5892004',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.language_outlined, size: 18, color: AppColors.emerald),
                        const SizedBox(width: 8),
                        Text(
                          settings.isUrdu ? 'ویب سائٹ: ' : 'Website: ',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const Expanded(
                          child: Text(
                            'https://azantechsolutions.pages.dev',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 5: App Info & Integrity Badge
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, color: AppColors.emerald, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '100% Offline & SQLCipher Encrypted',
                          style: TextStyle(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hisab Pro v1.0.0 — Powered by AzanTech Solutions',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, right: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.emerald,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _themeModeName(ThemeMode mode, bool isUrdu) {
    switch (mode) {
      case ThemeMode.light:
        return isUrdu ? 'روشن' : 'Light';
      case ThemeMode.dark:
        return isUrdu ? 'تاریک' : 'Dark';
      case ThemeMode.system:
        return isUrdu ? 'سسٹم' : 'System Default';
    }
  }

  void _showCurrencyPicker(
    BuildContext context,
    AppSettingsState settings,
    SettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _availableCurrencies.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final curr = _availableCurrencies[index];
          final isSelected = curr['code'] == settings.currencyCode;
          return ListTile(
            title: Text(curr['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.emerald) : null,
            onTap: () {
              notifier.setCurrency(curr['code']!, curr['symbol']!);
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}
