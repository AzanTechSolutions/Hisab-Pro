import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/backup/data/backup_service.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final keyDerivation = ref.watch(keyDerivationServiceProvider);
  return BackupService(
    databaseService: dbService,
    keyDerivation: keyDerivation,
  );
});
