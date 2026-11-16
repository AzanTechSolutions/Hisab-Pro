import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedNavIndex = 0;
  bool _isLoadingData = true;

  int _totalBalanceMinor = 0;
  int _totalIncomeMinor = 0;
  int _totalExpenseMinor = 0;
  int _loansGivenMinor = 0;
  int _loansTakenMinor = 0;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  static const _money = MoneyService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) {
      context.go('/auth');
      return;
    }

    final db = ref.read(activeDatabaseProvider);
    if (db == null) {
      context.go('/auth');
      return;
    }

    try {
      // 1. Fetch accounts
      final accountsData = await db.query(
        'accounts',
        where: 'user_id = ? AND is_archived = 0',
        whereArgs: [activeProfile.id],
      );

      int totalBalance = 0;
      for (final acc in accountsData) {
        totalBalance += (acc['current_balance_minor'] as int? ?? 0);
      }

      // 2. Fetch income and expense totals
      final incomeResult = await db.rawQuery(
        "SELECT SUM(amount_minor) as total FROM transactions WHERE user_id = ? AND type = 'income' AND status = 'posted'",
        [activeProfile.id],
      );
      final expenseResult = await db.rawQuery(
        "SELECT SUM(amount_minor) as total FROM transactions WHERE user_id = ? AND type = 'expense' AND status = 'posted'",
        [activeProfile.id],
      );

      final totalIncome = (incomeResult.first['total'] as int?) ?? 0;
      final totalExpense = (expenseResult.first['total'] as int?) ?? 0;

      // 3. Fetch loans receivables & payables
      final loansGivenResult = await db.rawQuery(
        "SELECT SUM(amount_minor) as total FROM loans WHERE user_id = ? AND loan_type = 'loan_given' AND status IN ('active', 'partial', 'overdue')",
        [activeProfile.id],
      );
      final loansTakenResult = await db.rawQuery(
        "SELECT SUM(amount_minor) as total FROM loans WHERE user_id = ? AND loan_type = 'loan_taken' AND status IN ('active', 'partial', 'overdue')",
        [activeProfile.id],
      );

      final loansGiven = (loansGivenResult.first['total'] as int?) ?? 0;
      final loansTaken = (loansTakenResult.first['total'] as int?) ?? 0;

      // 4. Fetch recent transactions
      final recentData = await db.query(
        'transactions',
        where: 'user_id = ?',
        whereArgs: [activeProfile.id],
        orderBy: 'transaction_date DESC, created_at DESC',
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _accounts = accountsData;
          _totalBalanceMinor = totalBalance;
          _totalIncomeMinor = totalIncome;
          _totalExpenseMinor = totalExpense;
          _loansGivenMinor = loansGiven;
          _loansTakenMinor = loansTaken;
          _recentTransactions = recentData;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handleLock() async {
    await ref.read(activeProfileProvider.notifier).lock();
    if (mounted) {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.emerald.withValues(alpha: 0.2),
              child: Text(
                profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'H',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lock Profile',
            icon: const Icon(Icons.lock_outline, color: AppColors.warning),
            onPressed: _handleLock,
          ),
          IconButton(
            tooltip: 'Switch User',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              ref.read(activeProfileProvider.notifier).lock();
              context.go('/profiles');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Balance Card
              _buildMainBalanceCard(isDark),
              const SizedBox(height: 16),

              // Income & Expense Summary Cards
              _buildCashFlowRow(),
              const SizedBox(height: 16),

              // Loan Receivables / Payables & Net Worth
              _buildLoansAndNetWorthRow(),
              const SizedBox(height: 22),

              // Accounts Overview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Accounts',
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () => context.push('/accounts').then((_) => _loadDashboardData()),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildAccountsList(isDark),
              const SizedBox(height: 22),

              // Quick Actions
              Text(
                'Quick Actions',
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              _buildQuickActionBar(),
              const SizedBox(height: 24),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () => context.push('/transactions').then((_) => _loadDashboardData()),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRecentTransactionsList(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedNavIndex = idx);
          if (idx == 1) context.push('/transactions').then((_) => _loadDashboardData());
          if (idx == 2) context.push('/loans').then((_) => _loadDashboardData());
          if (idx == 3) context.push('/reports').then((_) => _loadDashboardData());
          if (idx == 4) context.push('/settings').then((_) => _loadDashboardData());
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Loans'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildMainBalanceCard(bool isDark) {
    final balanceMajor = _money.fromMinorUnits(_totalBalanceMinor);
    final formattedBalance = _currencyFormat.format(balanceMajor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text('Encrypted', style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formattedBalance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.emeraldSoft, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_accounts.length} active account${_accounts.length == 1 ? '' : 's'} linked',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowRow() {
    final incomeMajor = _money.fromMinorUnits(_totalIncomeMinor);
    final expenseMajor = _money.fromMinorUnits(_totalExpenseMinor);

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Total Income',
            amount: _currencyFormat.format(incomeMajor),
            icon: Icons.arrow_downward,
            iconColor: AppColors.emerald,
            backgroundColor: AppColors.emerald.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Total Expenses',
            amount: _currencyFormat.format(expenseMajor),
            icon: Icons.arrow_upward,
            iconColor: AppColors.danger,
            backgroundColor: AppColors.danger.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _buildLoansAndNetWorthRow() {
    final loansGivenMajor = _money.fromMinorUnits(_loansGivenMinor);
    final loansTakenMajor = _money.fromMinorUnits(_loansTakenMinor);
    final netWorthMinor = _totalBalanceMinor + _loansGivenMinor - _loansTakenMinor;
    final netWorthMajor = _money.fromMinorUnits(netWorthMinor);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Receivable (Lent)',
                amount: _currencyFormat.format(loansGivenMajor),
                icon: Icons.call_made,
                iconColor: Colors.blueAccent,
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.08),
                onTap: () => context.push('/loans?type=loan_given').then((_) => _loadDashboardData()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Payable (Borrowed)',
                amount: _currencyFormat.format(loansTakenMajor),
                icon: Icons.call_received,
                iconColor: Colors.orangeAccent,
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.08),
                onTap: () => context.push('/loans?type=loan_taken').then((_) => _loadDashboardData()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 20, color: AppColors.emerald),
                  SizedBox(width: 8),
                  Text('Calculated Net Worth', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                _currencyFormat.format(netWorthMajor),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: backgroundColor,
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList(bool isDark) {
    if (_accounts.isEmpty) {
      return const Text('No accounts found', style: TextStyle(color: Colors.grey));
    }

    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final acc = _accounts[index];
          final bal = _money.fromMinorUnits(acc['current_balance_minor'] as int? ?? 0);
          final name = acc['name'] as String? ?? 'Account';
          final type = acc['account_type'] as String? ?? 'cash';

          IconData typeIcon = Icons.account_balance_wallet_outlined;
          if (type == 'bank') typeIcon = Icons.account_balance_outlined;
          if (type == 'wallet') typeIcon = Icons.phone_android_outlined;

          return Container(
            width: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Icon(typeIcon, size: 18, color: AppColors.emerald),
                  ],
                ),
                Text(
                  _currencyFormat.format(bal),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionButton(
            label: 'Add Income',
            icon: Icons.add_circle_outline,
            color: AppColors.emerald,
            onTap: () => context.push('/transactions/add?type=income').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Add Expense',
            icon: Icons.remove_circle_outline,
            color: AppColors.danger,
            onTap: () => context.push('/transactions/add?type=expense').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Transfer',
            icon: Icons.sync_alt,
            color: Colors.blueAccent,
            onTap: () => context.push('/transfers/add').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Give Loan',
            icon: Icons.arrow_outward,
            color: Colors.purpleAccent,
            onTap: () => context.push('/loans/add?type=loan_given').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Take Loan',
            icon: Icons.south_west,
            color: Colors.amber[800]!,
            onTap: () => context.push('/loans/add?type=loan_taken').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Budgets',
            icon: Icons.pie_chart_outline,
            color: Colors.teal,
            onTap: () => context.push('/budgets').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'People',
            icon: Icons.people_outline,
            color: Colors.indigoAccent,
            onTap: () => context.push('/people').then((_) => _loadDashboardData()),
          ),
          const SizedBox(width: 10),
          _actionButton(
            label: 'Backup',
            icon: Icons.security,
            color: AppColors.emerald,
            onTap: () => context.push('/backup'),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsList(bool isDark) {
    if (_recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_outlined, size: 36, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No transactions recorded yet',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = _recentTransactions[index];
        final isIncome = tx['type'] == 'income';
        final amountMajor = _money.fromMinorUnits(tx['amount_minor'] as int? ?? 0);
        final title = tx['title'] as String? ?? 'Transaction';

        return ListTile(
          tileColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: CircleAvatar(
            backgroundColor: (isIncome ? AppColors.emerald : AppColors.danger).withValues(alpha: 0.15),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? AppColors.emerald : AppColors.danger,
              size: 20,
            ),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(tx['payment_method'] as String? ?? 'Cash'),
          trailing: Text(
            '${isIncome ? '+' : '-'}${_currencyFormat.format(amountMajor)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isIncome ? AppColors.emerald : AppColors.danger,
            ),
          ),
        );
      },
    );
  }
}
