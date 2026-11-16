import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class LoanListScreen extends ConsumerStatefulWidget {
  const LoanListScreen({super.key, this.initialType = 'loan_given'});

  final String initialType; // 'loan_given' or 'loan_taken'

  @override
  ConsumerState<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends ConsumerState<LoanListScreen> {
  late String _activeType;
  static const _money = MoneyService();
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGiven = _activeType == 'loan_given';
    final loansAsync = ref.watch(loansByTypeProvider(_activeType));

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Loans & Debt Ledger'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'View Contacts',
            onPressed: () => context.push('/people'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Segmented Tabs: Given vs Taken
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabButton('loan_given', 'Money Lent (Receivables)', isGiven, Colors.blueAccent),
                    ),
                    Expanded(
                      child: _tabButton('loan_taken', 'Money Borrowed (Payables)', !isGiven, Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Loans Content
              Expanded(
                child: loansAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (loans) {
                    int totalPrincipal = 0;
                    int totalRepaid = 0;
                    int totalRemaining = 0;

                    for (final l in loans) {
                      totalPrincipal += l.amountMinor;
                      totalRepaid += l.totalRepaidMinor;
                      totalRemaining += l.remainingBalanceMinor;
                    }

                    return Column(
                      children: [
                        // Summary Banner
                        _buildSummaryBanner(isDark, isGiven, totalPrincipal, totalRepaid, totalRemaining),
                        const SizedBox(height: 14),

                        // Loans List
                        Expanded(
                          child: loans.isEmpty
                              ? _buildEmptyState(isGiven)
                              : ListView.separated(
                                  itemCount: loans.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final loan = loans[index];
                                    return _buildLoanCard(context, loan, isDark, isGiven);
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isGiven ? Colors.blueAccent : Colors.orangeAccent,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/loans/add?type=$_activeType').then((_) {
          ref.invalidate(loansByTypeProvider('loan_given'));
          ref.invalidate(loansByTypeProvider('loan_taken'));
        }),
        icon: const Icon(Icons.add),
        label: Text(isGiven ? 'Lend Money' : 'Borrow Money'),
      ),
    );
  }

  Widget _tabButton(String type, String label, bool isSelected, Color activeColor) {
    return InkWell(
      onTap: () => setState(() => _activeType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(
    bool isDark,
    bool isGiven,
    int principal,
    int repaid,
    int remaining,
  ) {
    final themeColor = isGiven ? Colors.blueAccent : Colors.orangeAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryColumn('Total ${isGiven ? 'Lent' : 'Borrowed'}', _currencyFormat.format(_money.fromMinorUnits(principal))),
          Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.2)),
          _summaryColumn(isGiven ? 'Recovered' : 'Repaid', _currencyFormat.format(_money.fromMinorUnits(repaid)), color: AppColors.emerald),
          Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.2)),
          _summaryColumn('Remaining', _currencyFormat.format(_money.fromMinorUnits(remaining)), color: themeColor),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyState(bool isGiven) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handshake_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            isGiven ? 'No money lent records' : 'No money borrowed records',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            isGiven
                ? 'Track money you lend to friends or family with due dates and installments.'
                : 'Track loans you have taken and plan repayments cleanly.',
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, Loan loan, bool isDark, bool isGiven) {
    final themeColor = isGiven ? Colors.blueAccent : Colors.orangeAccent;
    final remainingMajor = _money.fromMinorUnits(loan.remainingBalanceMinor);
    final principalMajor = _money.fromMinorUnits(loan.amountMinor);

    Color statusColor = Colors.blue;
    String statusLabel = 'Active';
    if (loan.isPaid) {
      statusColor = AppColors.emerald;
      statusLabel = 'Settled';
    } else if (loan.isOverdue) {
      statusColor = AppColors.danger;
      statusLabel = 'OVERDUE';
    } else if (loan.totalRepaidMinor > 0) {
      statusColor = Colors.orange;
      statusLabel = 'Partial';
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () => context.push('/loans/detail/${loan.id}').then((_) {
          ref.invalidate(loansByTypeProvider('loan_given'));
          ref.invalidate(loansByTypeProvider('loan_taken'));
        }),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Person & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: themeColor.withValues(alpha: 0.15),
                          child: Text(
                            loan.personName?.isNotEmpty == true ? loan.personName![0].toUpperCase() : 'L',
                            style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.personName ?? 'Contact',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (loan.personPhone != null)
                                Text(
                                  loan.personPhone!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Balances Row
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: loan.repaymentProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 10),

              // Footer: Due Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (loan.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: loan.isOverdue ? AppColors.danger : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(loan.dueDate!))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: loan.isOverdue ? AppColors.danger : AppColors.textSecondary,
                            fontWeight: loan.isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text('No due date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    '${(loan.repaymentProgress * 100).toStringAsFixed(0)}% Repaid',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

