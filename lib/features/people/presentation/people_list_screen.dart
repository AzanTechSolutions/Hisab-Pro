import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/loans/loans_providers.dart';
import 'package:hisab_pro/features/people/domain/person.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/shared/services/money_service.dart';
import 'package:intl/intl.dart';

class PeopleListScreen extends ConsumerStatefulWidget {
  const PeopleListScreen({super.key});

  @override
  ConsumerState<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends ConsumerState<PeopleListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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

  void _showPersonDialog({Person? existing}) {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Contact / Person' : 'Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Tariq Khan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number (Optional)', hintText: '0300-1234567'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (Optional)'),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                final user = ref.read(activeProfileProvider);
                if (user == null) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(peopleRepositoryProvider).deletePerson(user.id, existing.id);
                  ref.invalidate(peopleListProvider);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
            onPressed: () async {
              final user = ref.read(activeProfileProvider);
              if (user == null) return;
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(ctx);
              final repo = ref.read(peopleRepositoryProvider);

              if (existing == null) {
                await repo.createPerson(
                  userId: user.id,
                  fullName: name,
                  phoneNumber: phoneCtrl.text,
                  notes: notesCtrl.text,
                );
              } else {
                await repo.updatePerson(
                  userId: user.id,
                  personId: existing.id,
                  fullName: name,
                  phoneNumber: phoneCtrl.text,
                  notes: notesCtrl.text,
                );
              }
              ref.invalidate(peopleListProvider);
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
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        title: const Text('Contacts & People'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Person',
            onPressed: () => _showPersonDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search people by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: peopleAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (people) {
                    final filtered = _searchQuery.isEmpty
                        ? people
                        : people.where((p) {
                            return p.fullName.toLowerCase().contains(_searchQuery) ||
                                (p.phoneNumber != null && p.phoneNumber!.contains(_searchQuery));
                          }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No contacts found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emerald,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showPersonDialog(),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Contact'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        final net = person.netBalanceMinor;
                        final netMajor = _money.fromMinorUnits(net.abs());

                        Color netColor = Colors.grey;
                        String netLabel = 'Settled';
                        if (net > 0) {
                          netColor = AppColors.emerald;
                          netLabel = '+${_currencyFormat.format(netMajor)} (Receivable)';
                        } else if (net < 0) {
                          netColor = AppColors.danger;
                          netLabel = '-${_currencyFormat.format(netMajor)} (Payable)';
                        }

                        return Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                              child: Text(
                                person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : 'P',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald, fontSize: 18),
                              ),
                            ),
                            title: Text(person.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (person.phoneNumber != null && person.phoneNumber!.isNotEmpty)
                                  Text(person.phoneNumber!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  netLabel,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: netColor),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                              onPressed: () => _showPersonDialog(existing: person),
                            ),
                          ),
                        );
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
        onPressed: () => _showPersonDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('New Person'),
      ),
    );
  }
}

