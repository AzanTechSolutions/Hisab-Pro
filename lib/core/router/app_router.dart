import 'package:go_router/go_router.dart';
import 'package:hisab_pro/features/accounts/presentation/account_list_screen.dart';
import 'package:hisab_pro/features/authentication/auth_gate.dart';
import 'package:hisab_pro/features/audit/presentation/audit_log_screen.dart';
import 'package:hisab_pro/features/backup/presentation/backup_screen.dart';
import 'package:hisab_pro/features/budgets/presentation/budget_screen.dart';
import 'package:hisab_pro/features/dashboard/dashboard_screen.dart';
import 'package:hisab_pro/features/loans/presentation/loan_detail_screen.dart';
import 'package:hisab_pro/features/loans/presentation/loan_form_screen.dart';
import 'package:hisab_pro/features/loans/presentation/loan_list_screen.dart';
import 'package:hisab_pro/features/people/presentation/people_list_screen.dart';
import 'package:hisab_pro/features/reports/presentation/reports_screen.dart';
import 'package:hisab_pro/features/settings/presentation/settings_screen.dart';
import 'package:hisab_pro/features/transactions/presentation/transaction_form_screen.dart';
import 'package:hisab_pro/features/transactions/presentation/transaction_list_screen.dart';
import 'package:hisab_pro/features/transactions/presentation/transfer_form_screen.dart';
import 'package:hisab_pro/features/user_profiles/profile_create_screen.dart';
import 'package:hisab_pro/features/user_profiles/profile_select_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/auth',
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final profileId = state.uri.queryParameters['profileId'];
          return AuthGate(selectedProfileId: profileId);
        },
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) {
          return const ProfileSelectScreen();
        },
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) {
              return const ProfileCreateScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          return const DashboardScreen();
        },
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) {
          return const AccountListScreen();
        },
      ),
      GoRoute(
        path: '/people',
        builder: (context, state) {
          return const PeopleListScreen();
        },
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) {
          return const BudgetScreen();
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) {
          return const ReportsScreen();
        },
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) {
          return const BackupScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) {
          return const AuditLogScreen();
        },
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) {
          return const TransactionListScreen();
        },
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final type = state.uri.queryParameters['type'] ?? 'expense';
              return TransactionFormScreen(initialType: type);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/transfers/add',
        builder: (context, state) {
          return const TransferFormScreen();
        },
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'loan_given';
          return LoanListScreen(initialType: type);
        },
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final type = state.uri.queryParameters['type'] ?? 'loan_given';
              return LoanFormScreen(initialType: type);
            },
          ),
          GoRoute(
            path: 'detail/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return LoanDetailScreen(loanId: id);
            },
          ),
        ],
      ),
    ],
  );
}
