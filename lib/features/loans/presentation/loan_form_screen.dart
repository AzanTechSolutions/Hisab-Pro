import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/features/transactions/transactions_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  const LoanFormScreen({super.key, this.initialType = 'loan_given'});

  final String initialType; // 'loan_given' or 'loan_taken'

  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _loanType;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPersonId;
  String? _selectedAccountId;
  DateTime _loanDate = DateTime.now();
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _errorMessage;

  static const _money = MoneyService();

  @override
  void initState() {
    super.initState();
    _loanType = widget.initialType;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPersonId == null) {
      setState(() => _errorMessage = 'Please select a contact/person.');
      return;
    }
    if (_selectedAccountId == null) {
      setState(() => _errorMessage = 'Please select an account.');
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
      final repo = ref.read(loanRepositoryProvider);

      await repo.createLoan(
        userId: user.id,
        personId: _selectedPersonId!,
        loanType: _loanType,
        amountMinor: amountMinor,
        loanDate: _loanDate.millisecondsSinceEpoch,
        dueDate: _dueDate?.millisecondsSinceEpoch,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        accountId: _selectedAccountId!,
      );

      // Invalidate relevant providers
      ref.invalidate(loansByTypeProvider('loan_given'));
      ref.invalidate(loansByTypeProvider('loan_taken'));
      ref.invalidate(accountsListProvider);
      ref.invalidate(peopleListProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_loanType == 'loan_given' ? 'Money Lent' : 'Loan Taken'} recorded successfully!'),
            backgroundColor: _loanType == 'loan_given' ? Colors.blueAccent : Colors.orangeAccent,
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

  void _showAddPersonDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Asad Ali'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
            onPressed: () async {
              final user = ref.read(activeProfileProvider);
              if (user == null || nameCtrl.text.trim().isEmpty) return;

              Navigator.pop(ctx);
              final person = await ref.read(peopleRepositoryProvider).createPerson(
                    userId: user.id,
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                  );
              ref.invalidate(peopleListProvider);
              setState(() => _selectedPersonId = person.id);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGiven = _loanType == 'loan_given';
    final themeColor = isGiven ? Colors.blueAccent : Colors.orangeAccent;

    final peopleAsync = ref.watch(peopleListProvider);
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: Text(isGiven ? 'Lend Money (Receivable)' : 'Borrow Money (Payable)'),
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
                // Type Segment
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypeSegment('loan_given', 'Money Lent', Colors.blueAccent),
                        _buildTypeSegment('loan_taken', 'Money Borrowed', Colors.orangeAccent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Principal Amount (PKR)',
                        style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Rs. ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeColor)),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter amount';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

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

                // Person Selector with Quick Add Button
                peopleAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (people) {
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPersonId,
                            decoration: InputDecoration(
                              labelText: isGiven ? 'Debtor (Who owes you?)' : 'Creditor (Who lent you?)',
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            items: people.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.fullName),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedPersonId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.person_add),
                          tooltip: 'Add New Contact',
                          onPressed: _showAddPersonDialog,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Account Selector
                accountsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (accounts) {
                    if (_selectedAccountId == null && accounts.isNotEmpty) {
                      _selectedAccountId = accounts.first.id;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: InputDecoration(
                        labelText: isGiven ? 'Transfer Out From Account' : 'Deposit Into Account',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem<String>(
                          value: acc.id,
                          child: Text('${acc.name} (${acc.accountType})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAccountId = val),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Loan Date & Due Date Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _loanDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _loanDate = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Loan Date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(DateFormat('dd MMM yyyy').format(_loanDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date (Optional)',
                            prefixIcon: const Icon(Icons.event_outlined, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            _dueDate != null ? DateFormat('dd MMM yyyy').format(_dueDate!) : 'Not set',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Purpose / Description',
                    hintText: 'e.g. Business partnership, Personal emergency',
                    prefixIcon: const Icon(Icons.description_outlined),
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
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Save ${isGiven ? 'Lent Record' : 'Borrowed Record'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment(String type, String label, Color activeColor) {
    final isSelected = _loanType == type;
    return InkWell(
      onTap: () => setState(() => _loanType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

