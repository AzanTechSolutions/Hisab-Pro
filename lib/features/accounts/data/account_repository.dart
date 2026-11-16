import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/accounts/domain/account.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing user financial accounts.
class AccountRepository {
  AccountRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Retrieves all active accounts for [userId].
  Future<List<Account>> getAccounts(
    String userId, {
    bool includeArchived = false,
  }) async {
    final db = _dbService.getActiveDatabase(userId);
    final whereClause = includeArchived
        ? 'user_id = ?'
        : 'user_id = ? AND is_archived = 0';

    final rows = await db.query(
      'accounts',
      where: whereClause,
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) => Account.fromMap(row)).toList();
  }

  /// Retrieves a specific account by [accountId], validating [userId] ownership.
  Future<Account?> getAccountById(String userId, String accountId) async {
    final db = _dbService.getActiveDatabase(userId);
    final rows = await db.query(
      'accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  /// Creates a new financial account.
  Future<Account> createAccount({
    required String userId,
    required String name,
    required String accountType,
    int openingBalanceMinor = 0,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure('Account name cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final existing = await db.query(
      'accounts',
      where: 'user_id = ? AND LOWER(name) = ?',
      whereArgs: [userId, cleanName.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationFailure('An account with this name already exists.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final account = Account(
      id: _uuid.v4(),
      userId: userId,
      name: cleanName,
      accountType: accountType,
      currency: 'PKR',
      openingBalanceMinor: openingBalanceMinor,
      currentBalanceMinor: openingBalanceMinor,
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('accounts', account.toMap());
    AppLogger.info('Created account ${account.name} for user $userId');
    return account;
  }

  /// Updates existing account details.
  Future<void> updateAccount({
    required String userId,
    required String accountId,
    required String name,
    required String accountType,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure('Account name cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'accounts',
      {
        'name': cleanName,
        'account_type': accountType,
        'notes': notes?.trim(),
        'updated_at': now,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
    );
  }

  /// Archives or unarchives an account.
  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool isArchived,
  }) async {
    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'accounts',
      {
        'is_archived': isArchived ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
    );
  }

  /// Deletes an account only if no transactions or loans reference it.
  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    // Check if transactions exist
    final txCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE user_id = ? AND account_id = ?',
      [userId, accountId],
    )) ?? 0;

    // Check if loans exist
    final loanCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM loans WHERE user_id = ? AND account_id = ?',
      [userId, accountId],
    )) ?? 0;

    if (txCount > 0 || loanCount > 0) {
      throw const ValidationFailure(
        'Cannot delete account with existing transactions or loans. Please archive it instead.',
      );
    }

    await db.delete(
      'accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
    );
  }
}

