import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/audit/data/audit_repository.dart';
import 'package:hisab_pro/features/audit/domain/audit_event.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return AuditRepository(databaseService: dbService);
});

final selectedAuditCategoryProvider = StateProvider<String>((ref) => 'ALL');

final auditEventsListProvider = FutureProvider<List<AuditEvent>>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];

  final category = ref.watch(selectedAuditCategoryProvider);
  final repo = ref.watch(auditRepositoryProvider);

  return repo.getAuditEvents(activeProfile.id, category: category);
});
