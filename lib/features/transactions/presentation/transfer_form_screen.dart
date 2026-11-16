import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key});

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  DateTime _transferDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  static const _money = MoneyService();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == null || _toAccountId == null) {
      setState(() => _errorMessage = 'Please select both source and destination accounts.');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      setState(() => _errorMessage = 'Source and destination accounts must be different.');
      return;
    }

    final amountDouble = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amountDouble <= 0) {
      setState(() => _errorMessage = 'Amount must be greater than zero.');
      return;
    }

    final user = ref.read(activeProfileProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final amountMinor = _money.toMinorUnits(amountDouble);
      final repo = ref.read(transactionRepositoryProvider);

      await repo.createTransfer(
        userId: user.id,
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        amountMinor: amountMinor,
        transferDate: _transferDate.millisecondsSinceEpoch,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      ref.invalidate(accountsListProvider);
      ref.invalidate(filteredTransactionsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer executed successfully!'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Transfer Money'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sync_alt, size: 36, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Account to Account Transfer',
                    style: AppTextStyles.title.copyWith(fontSize: 18),
                  ),
                ),
                Center(
                  child: Text(
                    'Moves balance without affecting total income or expense.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                  ),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount (PKR)',
                    prefixText: 'Rs. ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // From Account
                accountsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (accounts) {
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _fromAccountId,
                          decoration: InputDecoration(
                            labelText: 'From Account (Source)',
                            prefixIcon: const Icon(Icons.arrow_upward, color: AppColors.danger),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Text(acc.name),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _fromAccountId = val),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _toAccountId,
                          decoration: InputDecoration(
                            labelText: 'To Account (Destination)',
                            prefixIcon: const Icon(Icons.arrow_downward, color: AppColors.emerald),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Text(acc.name),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _toAccountId = val),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Transfer Note (Optional)',
                    hintText: 'e.g. ATM cash withdrawal, Bank to Easypaisa',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleTransfer,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Execute Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

