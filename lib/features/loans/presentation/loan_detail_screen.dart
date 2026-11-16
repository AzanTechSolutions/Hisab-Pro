import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/loans/domain/loan_repayment.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class LoanDetailScreen extends ConsumerStatefulWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> {
  static const _money = MoneyService();
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  void _showRepaymentDialog(Loan loan) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedAccountId;
    DateTime repaymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final accountsAsync = ref.watch(accountsListProvider);
          final maxAllowedMajor = _money.fromMinorUnits(loan.remainingBalanceMinor);

          return AlertDialog(
            title: Text(loan.isGiven ? 'Record Repayment Received' : 'Record Repayment Paid'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remaining Balance: ${_currencyFormat.format(maxAllowedMajor)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Repayment Amount (PKR)',
                      prefixText: 'Rs. ',
                      helperText: 'Max: ${_currencyFormat.format(maxAllowedMajor)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  accountsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                    data: (accounts) {
                      if (selectedAccountId == null && accounts.isNotEmpty) {
                        selectedAccountId = accounts.first.id;
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedAccountId,
                        decoration: InputDecoration(
                          labelText: loan.isGiven ? 'Deposit Into Account' : 'Pay Out From Account',
                        ),
                        items: accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.id,
                            child: Text(acc.name),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedAccountId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
                onPressed: () async {
                  final user = ref.read(activeProfileProvider);
                  if (user == null || selectedAccountId == null) return;

                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount <= 0) return;

                  final amountMinor = _money.toMinorUnits(amount);

                  try {
                    Navigator.pop(ctx);
                    await ref.read(loanRepositoryProvider).recordRepayment(
                          userId: user.id,
                          loanId: loan.id,
                          amountMinor: amountMinor,
                          accountId: selectedAccountId!,
                          repaymentDate: repaymentDate.millisecondsSinceEpoch,
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                        );

                    ref.invalidate(loanDetailProvider(loan.id));
                    ref.invalidate(loanRepaymentsProvider(loan.id));
                    ref.invalidate(accountsListProvider);
                    ref.invalidate(loansByTypeProvider('loan_given'));
                    ref.invalidate(loansByTypeProvider('loan_taken'));

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Repayment recorded successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                },
                child: const Text('Record'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteLoan(Loan loan) async {
    final user = ref.read(activeProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: const Text(
          'Are you sure you want to delete this loan record? Account balance will be reversed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(loanRepositoryProvider).deleteLoan(
                      userId: user.id,
                      loanId: loan.id,
                    );
                ref.invalidate(loansByTypeProvider('loan_given'));
                ref.invalidate(loansByTypeProvider('loan_taken'));
                ref.invalidate(accountsListProvider);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan deleted & balance reversed.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRepayment(LoanRepayment repayment, Loan loan) async {
    final user = ref.read(activeProfileProvider);
    if (user == null) return;

    await ref.read(loanRepositoryProvider).deleteRepayment(
          userId: user.id,
          repaymentId: repayment.id,
        );

    ref.invalidate(loanDetailProvider(loan.id));
    ref.invalidate(loanRepaymentsProvider(loan.id));
    ref.invalidate(accountsListProvider);
    ref.invalidate(loansByTypeProvider('loan_given'));
    ref.invalidate(loansByTypeProvider('loan_taken'));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repayment reversed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loanAsync = ref.watch(loanDetailProvider(widget.loanId));
    final repaymentsAsync = ref.watch(loanRepaymentsProvider(widget.loanId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Loan Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          loanAsync.when(
            data: (loan) => loan != null
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _deleteLoan(loan),
                  )
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: SafeArea(
        child: loanAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (loan) {
            if (loan == null) {
              return const Center(child: Text('Loan record not found.'));
            }

            final isGiven = loan.isGiven;
            final themeColor = isGiven ? Colors.blueAccent : Colors.orangeAccent;
            final remainingMajor = _money.fromMinorUnits(loan.remainingBalanceMinor);
            final principalMajor = _money.fromMinorUnits(loan.amountMinor);
            final repaidMajor = _money.fromMinorUnits(loan.totalRepaidMinor);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Balance Overview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isGiven ? 'MONEY LENT (RECEIVABLE)' : 'MONEY BORROWED (PAYABLE)',
                              style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (loan.isPaid ? AppColors.emerald : themeColor).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                loan.isPaid ? 'PAID & SETTLED' : loan.status.toUpperCase(),
                                style: TextStyle(
                                  color: loan.isPaid ? AppColors.emerald : themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loan.personName ?? 'Contact',
                          style: AppTextStyles.headline.copyWith(fontSize: 24),
                        ),
                        if (loan.personPhone != null)
                          Text(loan.personPhone!, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),

                        // Balance Numbers
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Remaining Balance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFormat.format(remainingMajor),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Original Principal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFormat.format(principalMajor),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: loan.repaymentProgress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            color: AppColors.emerald,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recovered: ${_currencyFormat.format(repaidMajor)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(loan.repaymentProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Record Repayment Button (if not fully paid)
                  if (!loan.isPaid)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => _showRepaymentDialog(loan),
                        icon: const Icon(Icons.add_task),
                        label: Text(
                          isGiven ? 'Record Repayment Received' : 'Record Repayment Made',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Repayment History Section
                  Text(
                    'Repayment History',
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),

                  repaymentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error: $err'),
                    data: (repayments) {
                      if (repayments.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'No repayments recorded yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: repayments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final rep = repayments[index];
                          final repAmountMajor = _money.fromMinorUnits(rep.amountMinor);
                          final dateStr = DateFormat('dd MMM yyyy').format(
                            DateTime.fromMillisecondsSinceEpoch(rep.repaymentDate),
                          );

                          return ListTile(
                            tileColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1A10B981),
                              child: Icon(Icons.check, color: AppColors.emerald, size: 20),
                            ),
                            title: Text(
                              _currencyFormat.format(repAmountMajor),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.emerald),
                            ),
                            subtitle: Text('$dateStr • ${rep.accountName ?? 'Account'}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _deleteRepayment(rep, loan),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

