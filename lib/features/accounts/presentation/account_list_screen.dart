import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  static const _money = MoneyService();
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('My Accounts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Account',
            onPressed: () => _showAccountDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading accounts: $err')),
          data: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No accounts found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showAccountDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Account'),
                    ),
                  ],
                ),
              );
            }

            int totalBalanceMinor = 0;
            for (final a in accounts) {
              totalBalanceMinor += a.currentBalanceMinor;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Aggregate Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total In All Accounts',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(_money.fromMinorUnits(totalBalanceMinor)),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.emerald),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Accounts (${accounts.length})',
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.separated(
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final acc = accounts[index];
                        return _buildAccountTile(context, ref, acc, isDark);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        onPressed: () => _showAccountDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Account'),
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    WidgetRef ref,
    Account acc,
    bool isDark,
  ) {
    IconData icon = Icons.account_balance_wallet_outlined;
    Color iconColor = AppColors.emerald;

    if (acc.accountType == 'bank') {
      icon = Icons.account_balance_outlined;
      iconColor = Colors.blueAccent;
    } else if (acc.accountType == 'wallet') {
      icon = Icons.phone_android_outlined;
      iconColor = Colors.orangeAccent;
    } else if (acc.accountType == 'savings') {
      icon = Icons.savings_outlined;
      iconColor = Colors.purpleAccent;
    }

    final balanceMajor = _money.fromMinorUnits(acc.currentBalanceMinor);

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(
          '${acc.accountType.toUpperCase()} • Opening: ${_currencyFormat.format(_money.fromMinorUnits(acc.openingBalanceMinor))}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormat.format(balanceMajor),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: balanceMajor >= 0 ? null : AppColors.danger,
              ),
            ),
          ],
        ),
        onTap: () => _showAccountDialog(context, ref, existing: acc),
      ),
    );
  }

  void _showAccountDialog(BuildContext context, WidgetRef ref, {Account? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final openingBalCtrl = TextEditingController(
      text: existing != null ? _money.fromMinorUnits(existing.openingBalanceMinor).toStringAsFixed(0) : '0',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String selectedType = existing?.accountType ?? 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add New Account' : 'Edit Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g. Meezan Bank, JazzCash',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                    DropdownMenuItem(value: 'wallet', child: Text('Mobile Wallet (Easypaisa/JazzCash)')),
                    DropdownMenuItem(value: 'savings', child: Text('Savings Account')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                if (existing == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingBalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance (PKR)',
                      hintText: '0',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final user = ref.read(activeProfileProvider);
                  if (user != null) {
                    try {
                      await ref.read(accountRepositoryProvider).deleteAccount(
                            userId: user.id,
                            accountId: existing.id,
                          );
                      ref.invalidate(accountsListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                        );
                      }
                    }
                  }
                },
                child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
              onPressed: () async {
                final user = ref.read(activeProfileProvider);
                if (user == null) return;
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(ctx);
                final repo = ref.read(accountRepositoryProvider);

                if (existing == null) {
                  final openBal = double.tryParse(openingBalCtrl.text.trim()) ?? 0;
                  final minor = _money.toMinorUnits(openBal);
                  await repo.createAccount(
                    userId: user.id,
                    name: name,
                    accountType: selectedType,
                    openingBalanceMinor: minor,
                    notes: notesCtrl.text,
                  );
                } else {
                  await repo.updateAccount(
                    userId: user.id,
                    accountId: existing.id,
                    name: name,
                    accountType: selectedType,
                    notes: notesCtrl.text,
                  );
                }
                ref.invalidate(accountsListProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

