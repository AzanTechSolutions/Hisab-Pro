import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchController = TextEditingController();
  static const _money = MoneyService();
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(transactionFilterNotifierProvider.notifier).update(
          (state) => state.copyWith(query: val.trim().isNotEmpty ? val.trim() : null),
        );
  }

  void _onTypeFilterChanged(String type) {
    ref.read(transactionFilterNotifierProvider.notifier).update(
          (state) => state.copyWith(type: type),
        );
  }

  Future<void> _confirmDelete(FinancialTransaction tx) async {
    final user = ref.read(activeProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete "${tx.title}"? The account balance will be reversed automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(transactionRepositoryProvider).deleteTransaction(
                    userId: user.id,
                    transactionId: tx.id,
                  );
              ref.invalidate(filteredTransactionsProvider);
              ref.invalidate(accountsListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted & balance reversed.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final activeFilter = ref.watch(transactionFilterNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Transactions Ledger'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Transfer Money',
            onPressed: () => context.push('/transfers/add'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by title, notes, or memo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All', activeFilter.type == 'all'),
                    const SizedBox(width: 8),
                    _filterChip('income', 'Income', activeFilter.type == 'income', color: AppColors.emerald),
                    const SizedBox(width: 8),
                    _filterChip('expense', 'Expense', activeFilter.type == 'expense', color: AppColors.danger),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Transactions List
              Expanded(
                child: transactionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading transactions: $err')),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'No transactions recorded',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap the + button to record your first income or expense.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _buildTransactionCard(context, tx, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  Widget _filterChip(String type, String label, bool isSelected, {Color? color}) {
    final activeColor = color ?? AppColors.emerald;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : AppColors.textSecondary,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => _onTypeFilterChanged(type),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    FinancialTransaction tx,
    bool isDark,
  ) {
    final isIncome = tx.isIncome;
    final amountMajor = _money.fromMinorUnits(tx.amountMinor);
    final themeColor = isIncome ? AppColors.emerald : AppColors.danger;
    final dateStr = DateFormat('dd MMM yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(tx.transactionDate),
    );

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: themeColor.withValues(alpha: 0.12),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: themeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          tx.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isIncome ? '+' : '-'}${_currencyFormat.format(amountMajor)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (tx.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.categoryName!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      Text(
                        tx.accountName ?? 'Account',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '• $dateStr',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx.notes!,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _confirmDelete(tx),
            ),
          ],
        ),
      ),
    );
  }
}

