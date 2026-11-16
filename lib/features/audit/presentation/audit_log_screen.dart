import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/audit/audit_providers.dart';
import 'package:hisab_pro/features/audit/domain/audit_event.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  static final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  static const List<String> _categories = [
    'ALL',
    'TRANSACTION',
    'ACCOUNT',
    'LOAN',
    'BACKUP',
    'SECURITY',
  ];

  void _showEventDetail(BuildContext context, AuditEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(event.eventType),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Event ID', event.id),
              _detailRow('Category', event.eventCategory),
              if (event.entityType != null) _detailRow('Entity Type', event.entityType!),
              if (event.entityId != null) _detailRow('Entity ID', event.entityId!),
              _detailRow('Timestamp', _dateFormatter.format(event.createdAt)),
              const SizedBox(height: 12),
              const Text('Metadata Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  event.metadata.isNotEmpty
                      ? const JsonEncoder.withIndent('  ').convert(event.metadata)
                      : 'No metadata recorded',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(auditEventsListProvider);
    final selectedCategory = ref.watch(selectedAuditCategoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail & Event Log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(auditEventsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.emerald.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.emerald,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.emerald : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      ref.read(selectedAuditCategoryProvider.notifier).state = cat;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Events List
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load audit events: $err')),
              data: (events) {
                if (events.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No audit events found in this category'),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final color = _getCategoryColor(event.eventCategory);
                    final icon = _getCategoryIcon(event.eventCategory);

                    return Card(
                      color: isDark ? AppColors.navy : Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              event.eventType,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                event.eventCategory,
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                _dateFormatter.format(event.createdAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showEventDetail(context, event),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TRANSACTION':
        return AppColors.emerald;
      case 'ACCOUNT':
        return Colors.blue;
      case 'LOAN':
        return Colors.purple;
      case 'BACKUP':
        return Colors.teal;
      case 'SECURITY':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'TRANSACTION':
        return Icons.receipt_long;
      case 'ACCOUNT':
        return Icons.account_balance;
      case 'LOAN':
        return Icons.handshake;
      case 'BACKUP':
        return Icons.cloud_sync;
      case 'SECURITY':
        return Icons.security;
      default:
        return Icons.event_note;
    }
  }
}
