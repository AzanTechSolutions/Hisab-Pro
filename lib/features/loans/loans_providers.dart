import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/loans/data/loan_repository.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/loans/domain/loan_repayment.dart';
import 'package:hisab_pro/features/people/data/people_repository.dart';
import 'package:hisab_pro/features/people/domain/person.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return PeopleRepository(databaseService: dbService);
});

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return LoanRepository(databaseService: dbService);
});

/// Fetches all contacts/people with calculated loan balances.
final peopleListProvider = FutureProvider<List<Person>>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final repo = ref.watch(peopleRepositoryProvider);
  return repo.getPeople(activeProfile.id);
});

/// Fetches loans filtered by type ('loan_given' or 'loan_taken' or null for all).
final loansByTypeProvider = FutureProvider.family<List<Loan>, String?>((ref, type) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getLoans(activeProfile.id, loanType: type);
});

/// Fetches single loan details by ID.
final loanDetailProvider = FutureProvider.family<Loan?, String>((ref, loanId) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return null;
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getLoanById(activeProfile.id, loanId);
});

/// Fetches repayment records for a loan.
final loanRepaymentsProvider = FutureProvider.family<List<LoanRepayment>, String>((ref, loanId) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getRepaymentsForLoan(activeProfile.id, loanId);
});

