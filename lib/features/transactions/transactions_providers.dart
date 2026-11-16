import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/accounts/data/account_repository.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:hisab_pro/features/categories/data/category_repository.dart';
import 'package:hisab_pro/features/categories/domain/category.dart';
import 'package:hisab_pro/features/transactions/data/transaction_repository.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return AccountRepository(databaseService: dbService);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return CategoryRepository(databaseService: dbService);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return TransactionRepository(databaseService: dbService);
});

/// Fetches all active accounts for the current user.
final accountsListProvider = FutureProvider<List<Account>>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getAccounts(activeProfile.id);
});

/// Fetches categories by type ('income' or 'expense').
final categoriesByTypeProvider = FutureProvider.family<List<Category>, String?>((ref, type) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getCategories(activeProfile.id, type: type);
});

/// Filter state for the transactions list.
class TransactionFilterState {
  const TransactionFilterState({
    this.type = 'all',
    this.accountId,
    this.categoryId,
    this.query,
    this.startDate,
    this.endDate,
  });

  final String type; // 'all', 'income', 'expense'
  final String? accountId;
  final String? categoryId;
  final String? query;
  final int? startDate;
  final int? endDate;

  TransactionFilterState copyWith({
    String? type,
    String? accountId,
    String? categoryId,
    String? query,
    int? startDate,
    int? endDate,
  }) {
    return TransactionFilterState(
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      query: query ?? this.query,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

final transactionFilterNotifierProvider = StateProvider<TransactionFilterState>((ref) {
  return const TransactionFilterState();
});

/// Loads transactions with active filters.
final filteredTransactionsProvider = FutureProvider<List<FinancialTransaction>>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final filter = ref.watch(transactionFilterNotifierProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  return repo.getTransactions(
    activeProfile.id,
    type: filter.type,
    accountId: filter.accountId,
    categoryId: filter.categoryId,
    startDate: filter.startDate,
    endDate: filter.endDate,
    query: filter.query,
  );
});

