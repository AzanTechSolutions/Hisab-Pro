import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/budgets/data/budget_repository.dart';
import 'package:hisab_pro/features/budgets/domain/budget.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return BudgetRepository(databaseService: dbService);
});

class SelectedBudgetPeriod {
  const SelectedBudgetPeriod({required this.year, required this.month});
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedBudgetPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

final selectedBudgetPeriodProvider = StateProvider<SelectedBudgetPeriod>((ref) {
  final now = DateTime.now();
  return SelectedBudgetPeriod(year: now.year, month: now.month);
});

/// Fetches budget for the currently selected period.
final currentBudgetProvider = FutureProvider<Budget?>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return null;
  final period = ref.watch(selectedBudgetPeriodProvider);
  final repo = ref.watch(budgetRepositoryProvider);

  return repo.getBudgetForMonth(activeProfile.id, period.year, period.month);
});

