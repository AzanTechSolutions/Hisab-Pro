import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/transactions/domain/transaction_model.dart';
import 'package:hisab_pro/features/transactions/domain/transfer_model.dart';
import 'package:uuid/uuid.dart';

/// Core transaction repository handling income, expenses, and linked transfers.
class TransactionRepository {
  TransactionRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Creates an income or expense transaction and atomically updates the account balance.
  Future<FinancialTransaction> createTransaction({
    required String userId,
    required String accountId,
    String? categoryId,
    String? personId,
    required String type, // 'income' or 'expense'
    required String title,
    required int amountMinor,
    String? paymentMethod,
    required int transactionDate,
    int? transactionTime,
    String? notes,
    String? attachmentId,
  }) async {
    if (amountMinor <= 0) {
      throw const ValidationFailure('Transaction amount must be greater than zero.');
    }
    if (type != 'income' && type != 'expense') {
      throw const ValidationFailure('Type must be either income or expense.');
    }

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ValidationFailure('Title cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final txId = _uuid.v4();

    final tx = FinancialTransaction(
      id: txId,
      userId: userId,
      accountId: accountId,
      categoryId: categoryId,
      personId: personId,
      type: type,
      title: cleanTitle,
      amountMinor: amountMinor,
      paymentMethod: paymentMethod,
      transactionDate: transactionDate,
      transactionTime: transactionTime,
      notes: notes?.trim(),
      attachmentId: attachmentId,
      status: 'posted',
      createdAt: now,
      updatedAt: now,
    );

    // Atomic execution
    await db.transaction((txn) async {
      // 1. Insert transaction row
      await txn.insert('transactions', tx.toMap());

      // 2. Adjust account balance
      final balanceDelta = (type == 'income') ? amountMinor : -amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [balanceDelta, now, accountId, userId],
      );

      // 3. Log audit event
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'transaction_created',
        'event_category': 'accounting',
        'entity_type': 'transactions',
        'entity_id': txId,
        'metadata_json': '{"type":"$type","amount":$amountMinor}',
        'created_at': now,
      });
    });

    AppLogger.info('Recorded $type: "$cleanTitle" (amount: $amountMinor) on account $accountId');
    return tx;
  }

  /// Records a linked account-to-account transfer.
  /// Deducts from [fromAccountId] and credits to [toAccountId] atomically.
  Future<AccountTransfer> createTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required int transferDate,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw const ValidationFailure('Source and destination accounts must be different.');
    }
    if (amountMinor <= 0) {
      throw const ValidationFailure('Transfer amount must be greater than zero.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final transferId = _uuid.v4();

    final transfer = AccountTransfer(
      id: transferId,
      userId: userId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amountMinor: amountMinor,
      transferDate: transferDate,
      note: note?.trim(),
      status: 'posted',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Insert transfer entry
      await txn.insert('transfers', transfer.toMap());

      // 2. Debit source account
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor - ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [amountMinor, now, fromAccountId, userId],
      );

      // 3. Credit destination account
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [amountMinor, now, toAccountId, userId],
      );

      // 4. Log audit event
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'transfer_executed',
        'event_category': 'accounting',
        'entity_type': 'transfers',
        'entity_id': transferId,
        'metadata_json': '{"amount":$amountMinor,"from":"$fromAccountId","to":"$toAccountId"}',
        'created_at': now,
      });
    });

    AppLogger.info('Executed transfer: $amountMinor from $fromAccountId to $toAccountId');
    return transfer;
  }

  /// Deletes a transaction and reverses its balance effect on the linked account.
  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    final existing = await db.query(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [transactionId, userId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw const ValidationFailure('Transaction not found.');
    }

    final tx = FinancialTransaction.fromMap(existing.first);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Reverse balance change
      final reverseDelta = (tx.type == 'income') ? -tx.amountMinor : tx.amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [reverseDelta, now, tx.accountId, userId],
      );

      // 2. Delete the transaction record
      await txn.delete(
        'transactions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [transactionId, userId],
      );

      // 3. Audit log
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'transaction_deleted',
        'event_category': 'accounting',
        'entity_type': 'transactions',
        'entity_id': transactionId,
        'metadata_json': '{"reversed_amount":${tx.amountMinor}}',
        'created_at': now,
      });
    });

    AppLogger.info('Deleted and reversed transaction: $transactionId');
  }

  /// Retrieves filtered transactions joined with account and category names.
  Future<List<FinancialTransaction>> getTransactions(
    String userId, {
    String? type, // 'income', 'expense', or null for all
    String? accountId,
    String? categoryId,
    int? startDate,
    int? endDate,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    final whereParts = <String>['t.user_id = ?'];
    final whereArgs = <dynamic>[userId];

    if (type != null && type != 'all') {
      whereParts.add('t.type = ?');
      whereArgs.add(type);
    }
    if (accountId != null) {
      whereParts.add('t.account_id = ?');
      whereArgs.add(accountId);
    }
    if (categoryId != null) {
      whereParts.add('t.category_id = ?');
      whereArgs.add(categoryId);
    }
    if (startDate != null) {
      whereParts.add('t.transaction_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereParts.add('t.transaction_date <= ?');
      whereArgs.add(endDate);
    }
    if (query != null && query.trim().isNotEmpty) {
      whereParts.add('(t.title LIKE ? OR t.notes LIKE ?)');
      final term = '%${query.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final sql = '''
      SELECT 
        t.*,
        a.name AS account_name,
        c.name AS category_name,
        c.color_hex AS category_color,
        c.icon_key AS category_icon
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE ${whereParts.join(' AND ')}
      ORDER BY t.transaction_date DESC, t.created_at DESC
      LIMIT $limit OFFSET $offset
    ''';

    final rows = await db.rawQuery(sql, whereArgs);
    return rows.map((r) => FinancialTransaction.fromMap(r)).toList();
  }

  /// Retrieves transfer records with joined account names.
  Future<List<AccountTransfer>> getTransfers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _dbService.getActiveDatabase(userId);
    final sql = '''
      SELECT 
        tr.*,
        from_acc.name AS from_account_name,
        to_acc.name AS to_account_name
      FROM transfers tr
      LEFT JOIN accounts from_acc ON tr.from_account_id = from_acc.id
      LEFT JOIN accounts to_acc ON tr.to_account_id = to_acc.id
      WHERE tr.user_id = ?
      ORDER BY tr.transfer_date DESC, tr.created_at DESC
      LIMIT $limit OFFSET $offset
    ''';

    final rows = await db.rawQuery(sql, [userId]);
    return rows.map((r) => AccountTransfer.fromMap(r)).toList();
  }
}

