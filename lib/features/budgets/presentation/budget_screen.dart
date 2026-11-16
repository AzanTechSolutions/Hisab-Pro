import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/budgets/budgets_providers.dart';
import 'package:hisab_pro/features/budgets/domain/budget.dart';
import 'package:hisab_pro/features/categories/domain/category.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  static const _money = MoneyService();
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  void _showSetBudgetDialog(BuildContext context, WidgetRef ref, Budget? existing) {
    final period = ref.read(selectedBudgetPeriodProvider);
    final limitCtrl = TextEditingController(
      text: existing != null ? _money.fromMinorUnits(existing.totalLimitMinor).toStringAsFixed(0) : '',
    );
    final thresholdCtrl = TextEditingController(
      text: existing != null ? existing.notificationThresholdPercent.toString() : '80',
    );
    final categoryLimitCtrls = <String, TextEditingController>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final expenseCategoriesAsync = ref.watch(categoriesByTypeProvider('expense'));

          return AlertDialog(
            title: Text('Set Budget for ${DateFormat('MMMM yyyy').format(DateTime(period.year, period.month))}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: limitCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Total Monthly Budget (PKR)',
                      prefixText: 'Rs. ',
                      hintText: 'e.g. 50000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: thresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Warning Threshold (%)',
                      suffixText: '%',
                      hintText: '80',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category Allocations (Optional):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  expenseCategoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                    data: (categories) {
                      return Column(
                        children: categories.map((cat) {
                          if (!categoryLimitCtrls.containsKey(cat.id)) {
                            final alloc = existing?.categoryAllocations.where((a) => a.categoryId == cat.id).firstOrNull;
                            categoryLimitCtrls[cat.id] = TextEditingController(
                              text: alloc != null ? _money.fromMinorUnits(alloc.limitMinor).toStringAsFixed(0) : '',
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: categoryLimitCtrls[cat.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: cat.name,
                                prefixText: 'Rs. ',
                                isDense: true,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                  if (user == null) return;

                  final limitDouble = double.tryParse(limitCtrl.text.trim()) ?? 0;
                  if (limitDouble <= 0) return;

                  final limitMinor = _money.toMinorUnits(limitDouble);
                  final threshold = int.tryParse(thresholdCtrl.text.trim()) ?? 80;

                  final categoryLimits = <String, int>{};
                  categoryLimitCtrls.forEach((catId, ctrl) {
                    final val = double.tryParse(ctrl.text.trim()) ?? 0;
                    if (val > 0) categoryLimits[catId] = _money.toMinorUnits(val);
                  });

                  Navigator.pop(ctx);
                  await ref.read(budgetRepositoryProvider).setMonthlyBudget(
                        userId: user.id,
                        name: 'Monthly Budget',
                        year: period.year,
                        month: period.month,
                        totalLimitMinor: limitMinor,
                        notificationThresholdPercent: threshold,
                        categoryLimitsMinor: categoryLimits,
                      );

                  ref.invalidate(currentBudgetProvider);
                },
                child: const Text('Save Budget'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = ref.watch(selectedBudgetPeriodProvider);
    final budgetAsync = ref.watch(currentBudgetProvider);

    final monthName = DateFormat('MMMM yyyy').format(DateTime(period.year, period.month));

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Budgets & Spending Limits'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Month Selector Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        final prev = DateTime(period.year, period.month - 1);
                        ref.read(selectedBudgetPeriodProvider.notifier).state =
                            SelectedBudgetPeriod(year: prev.year, month: prev.month);
                      },
                    ),
                    Text(
                      monthName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        final next = DateTime(period.year, period.month + 1);
                        ref.read(selectedBudgetPeriodProvider.notifier).state =
                            SelectedBudgetPeriod(year: next.year, month: next.month);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Budget View
              Expanded(
                child: budgetAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (budget) {
                    if (budget == null) {
                      return _buildEmptyBudgetState(context, ref);
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOverallBudgetCard(context, ref, budget, isDark),
                          const SizedBox(height: 24),
                          if (budget.categoryAllocations.isNotEmpty) ...[
                            Text(
                              'Category Allocations',
                              style: AppTextStyles.title.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: budget.categoryAllocations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final alloc = budget.categoryAllocations[index];
                                return _buildCategoryAllocationTile(alloc, isDark);
                              },
                            ),
                            const SizedBox(height: 30),
                          ],
                        ],
                      ),
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
        onPressed: () {
          final current = budgetAsync.asData?.value;
          _showSetBudgetDialog(context, ref, current);
        },
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Edit Budget'),
      ),
    );
  }

  Widget _buildEmptyBudgetState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('No budget set for this month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Set monthly spending limits to prevent overspending.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
            onPressed: () => _showSetBudgetDialog(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Set Monthly Budget'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallBudgetCard(BuildContext context, WidgetRef ref, Budget budget, bool isDark) {
    final limitMajor = _money.fromMinorUnits(budget.totalLimitMinor);
    final spentMajor = _money.fromMinorUnits(budget.spentMinor);
    final remainingMajor = _money.fromMinorUnits(budget.remainingMinor);

    Color statusColor = AppColors.emerald;
    String statusText = 'On Track';
    if (budget.isOverBudget) {
      statusColor = AppColors.danger;
      statusText = 'OVER BUDGET';
    } else if (budget.isWarning) {
      statusColor = AppColors.warning;
      statusText = 'Near Limit';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MONTHLY BUDGET STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(spentMajor),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: statusColor),
          ),
          Text(
            'Spent of ${_currencyFormat.format(limitMajor)} total limit',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budget.progress,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              color: statusColor,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining: ${_currencyFormat.format(remainingMajor)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${budget.utilizationPercentage.toStringAsFixed(1)}% Used',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAllocationTile(BudgetCategoryAllocation alloc, bool isDark) {
    final limitMajor = _money.fromMinorUnits(alloc.limitMinor);
    final spentMajor = _money.fromMinorUnits(alloc.spentMinor);
    final isOver = alloc.isOverBudget;
    final color = isOver ? AppColors.danger : AppColors.emerald;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(alloc.categoryName ?? 'Category', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '${_currencyFormat.format(spentMajor)} / ${_currencyFormat.format(limitMajor)}',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: alloc.progress,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

