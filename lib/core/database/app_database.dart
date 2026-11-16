import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

class DatabaseSchemaVersion {
  const DatabaseSchemaVersion._();

  static const int current = 1;
}

class DatabaseEntity {
  const DatabaseEntity({
    required this.name,
    required this.description,
    required this.userOwned,
  });

  final String name;
  final String description;
  final bool userOwned;
}

class DatabaseBootstrapConfig {
  const DatabaseBootstrapConfig({
    required this.profileId,
    required this.databaseFilename,
    required this.encryptionKeyAlias,
    required this.schemaVersion,
  });

  final String profileId;
  final String databaseFilename;
  final String encryptionKeyAlias;
  final int schemaVersion;
}

class AppDatabase {
  const AppDatabase();

  static const List<DatabaseEntity> requiredEntities = [
    DatabaseEntity(
      name: 'user_profiles',
      description: 'Local user profile metadata',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'accounts',
      description: 'Bank and cash account records',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'categories',
      description: 'Income and expense categories',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'transactions',
      description: 'Ledger transactions',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'transfers',
      description: 'Account-to-account transfer events',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'people',
      description: 'Person and contact relationships',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'loans',
      description: 'Lent and borrowed records',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'loan_repayments',
      description: 'Repayment ledger events',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'budgets',
      description: 'Monthly budget records',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'budget_categories',
      description: 'Category budget allocations',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'attachments',
      description: 'Local attachment metadata',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'reminders',
      description: 'Local reminder records',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'app_settings',
      description: 'Per-user settings',
      userOwned: true,
    ),
    DatabaseEntity(
      name: 'audit_events',
      description: 'Operational and security audit trail',
      userOwned: true,
    ),
  ];

  static String generateDatabaseFilename(String profileId) {
    // Generate clean filename while preserving safety and avoiding collision
    final safeName = profileId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'hisab_${safeName}.db';
  }

  static String generateEncryptionKeyAlias(String profileId) {
    return 'profile_${profileId}_db_key';
  }

  static String generateSecureRandomKey({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

class DatabaseMigrationPlan {
  const DatabaseMigrationPlan({
    required this.fromVersion,
    required this.toVersion,
  });

  final int fromVersion;
  final int toVersion;

  List<String> get steps {
    final steps = <String>[];

    for (var version = fromVersion; version < toVersion; version++) {
      steps.add('apply schema migration v$version -> v${version + 1}');
    }

    return steps;
  }
}

@immutable
class DatabaseIntegrityResult {
  const DatabaseIntegrityResult({
    required this.isValid,
    required this.checkedTables,
    required this.message,
  });

  final bool isValid;
  final List<String> checkedTables;
  final String message;
}
