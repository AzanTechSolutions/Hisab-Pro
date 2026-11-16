import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/loans/domain/loan.dart';
import 'package:hisab_pro/features/loans/domain/loan_repayment.dart';
import 'package:uuid/uuid.dart';

/// Repository managing loans (receivables/payables) and immutable repayment events.
class LoanRepository {
  LoanRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Creates a new loan (loan_given or loan_taken) and adjusts the linked account balance atomically.
  Future<Loan> createLoan({
    required String userId,
    required String personId,
    required String loanType, // 'loan_given' or 'loan_taken'
    required int amountMinor,
    double interestRatePercent = 0.0,
    required int loanDate,
    int? dueDate,
    String? description,
    String? notes,
    required String accountId,
  }) async {
    if (amountMinor <= 0) {
      throw const ValidationFailure('Loan amount must be greater than zero.');
    }
    if (loanType != 'loan_given' && loanType != 'loan_taken') {
      throw const ValidationFailure('Invalid loan type.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final loanId = _uuid.v4();

    final loan = Loan(
      id: loanId,
      userId: userId,
      personId: personId,
      loanType: loanType,
      amountMinor: amountMinor,
      interestRatePercent: interestRatePercent,
      loanDate: loanDate,
      dueDate: dueDate,
      description: description?.trim(),
      notes: notes?.trim(),
      accountId: accountId,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Insert loan record
      await txn.insert('loans', loan.toMap());

      // 2. Adjust account balance:
      // loan_given -> money lent OUT from account (negative delta)
      // loan_taken -> money borrowed IN to account (positive delta)
      final balanceDelta = (loanType == 'loan_given') ? -amountMinor : amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [balanceDelta, now, accountId, userId],
      );

      // 3. Log audit event
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'loan_created',
        'event_category': 'loans',
        'entity_type': 'loans',
        'entity_id': loanId,
        'metadata_json': '{"loan_type":"$loanType","amount":$amountMinor,"person_id":"$personId"}',
        'created_at': now,
      });
    });

    AppLogger.info('Created $loanType for person $personId: $amountMinor');
    return loan;
  }

  /// Records a partial or full repayment against an existing loan.
  /// Updates linked account and marks loan as 'partial' or 'paid' atomically.
  Future<LoanRepayment> recordRepayment({
    required String userId,
    required String loanId,
    required int amountMinor,
    required String accountId,
    required int repaymentDate,
    String? notes,
    String? paymentMethod,
  }) async {
    if (amountMinor <= 0) {
      throw const ValidationFailure('Repayment amount must be greater than zero.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final loan = await getLoanById(userId, loanId);

    if (loan == null) {
      throw const ValidationFailure('Loan record not found.');
    }
    if (loan.isPaid) {
      throw const ValidationFailure('This loan is already fully settled.');
    }

    // Overpayment check
    final newTotalRepaid = loan.totalRepaidMinor + amountMinor;
    if (newTotalRepaid > loan.amountMinor) {
      final maxAllowed = loan.amountMinor - loan.totalRepaidMinor;
      throw ValidationFailure(
        'Repayment exceeds remaining balance. Maximum allowed is ${maxAllowed / 100} PKR.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final repaymentId = _uuid.v4();

    final repayment = LoanRepayment(
      id: repaymentId,
      userId: userId,
      loanId: loanId,
      repaymentDate: repaymentDate,
      amountMinor: amountMinor,
      accountId: accountId,
      notes: notes?.trim(),
      paymentMethod: paymentMethod ?? 'Cash',
      status: 'posted',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Insert repayment ledger event
      await txn.insert('loan_repayments', repayment.toMap());

      // 2. Adjust account balance:
      // loan_given repayment -> receiving money back (positive delta)
      // loan_taken repayment -> paying money back (negative delta)
      final balanceDelta = (loan.isGiven) ? amountMinor : -amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [balanceDelta, now, accountId, userId],
      );

      // 3. Update loan status
      final newStatus = (newTotalRepaid >= loan.amountMinor) ? 'paid' : 'partial';
      await txn.update(
        'loans',
        {
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [loanId, userId],
      );

      // 4. Audit event
      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'loan_repayment_recorded',
        'event_category': 'loans',
        'entity_type': 'loan_repayments',
        'entity_id': repaymentId,
        'metadata_json': '{"loan_id":"$loanId","amount":$amountMinor,"status":"$newStatus"}',
        'created_at': now,
      });
    });

    AppLogger.info('Recorded repayment: $amountMinor for loan $loanId');
    return repayment;
  }

  /// Deletes a loan and reverses initial account balance effect.
  Future<void> deleteLoan({
    required String userId,
    required String loanId,
  }) async {
    final db = _dbService.getActiveDatabase(userId);
    final loan = await getLoanById(userId, loanId);

    if (loan == null) {
      throw const ValidationFailure('Loan record not found.');
    }

    if (loan.totalRepaidMinor > 0) {
      throw const ValidationFailure(
        'Cannot delete loan with active repayments. Delete all repayments first.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Revert account balance effect:
      // loan_given -> was negative, so add back
      // loan_taken -> was positive, so deduct back
      final reverseDelta = (loan.isGiven) ? loan.amountMinor : -loan.amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [reverseDelta, now, loan.accountId, userId],
      );

      await txn.delete(
        'loans',
        where: 'id = ? AND user_id = ?',
        whereArgs: [loanId, userId],
      );

      await txn.insert('audit_events', {
        'id': _uuid.v4(),
        'user_id': userId,
        'event_type': 'loan_deleted',
        'event_category': 'loans',
        'entity_type': 'loans',
        'entity_id': loanId,
        'metadata_json': '{"reverted_amount":${loan.amountMinor}}',
        'created_at': now,
      });
    });

    AppLogger.info('Deleted and reversed loan: $loanId');
  }

  /// Deletes a repayment event and reverses the account and loan status effect.
  Future<void> deleteRepayment({
    required String userId,
    required String repaymentId,
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    final rows = await db.query(
      'loan_repayments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [repaymentId, userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw const ValidationFailure('Repayment record not found.');
    }

    final repayment = LoanRepayment.fromMap(rows.first);
    final loan = await getLoanById(userId, repayment.loanId);
    if (loan == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Reverse account balance effect
      final reverseDelta = (loan.isGiven) ? -repayment.amountMinor : repayment.amountMinor;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance_minor = current_balance_minor + ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [reverseDelta, now, repayment.accountId, userId],
      );

      // Delete repayment row
      await txn.delete(
        'loan_repayments',
        where: 'id = ? AND user_id = ?',
        whereArgs: [repaymentId, userId],
      );

      // Recalculate remaining total
      final newTotalRepaid = loan.totalRepaidMinor - repayment.amountMinor;
      final newStatus = (newTotalRepaid <= 0) ? 'active' : 'partial';

      await txn.update(
        'loans',
        {
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [loan.id, userId],
      );
    });

    AppLogger.info('Deleted repayment: $repaymentId');
  }

  /// Retrieves filtered loans with person and account names and total repaid amounts.
  Future<List<Loan>> getLoans(
    String userId, {
    String? loanType, // 'loan_given' or 'loan_taken'
    String? personId,
    String? status, // 'active', 'paid', etc.
  }) async {
    final db = _dbService.getActiveDatabase(userId);

    final whereParts = <String>['l.user_id = ?'];
    final whereArgs = <dynamic>[userId];

    if (loanType != null) {
      whereParts.add('l.loan_type = ?');
      whereArgs.add(loanType);
    }
    if (personId != null) {
      whereParts.add('l.person_id = ?');
      whereArgs.add(personId);
    }
    if (status != null) {
      whereParts.add('l.status = ?');
      whereArgs.add(status);
    }

    final sql = '''
      SELECT 
        l.*,
        p.full_name AS person_name,
        p.phone_number AS person_phone,
        a.name AS account_name,
        COALESCE((
          SELECT SUM(lr.amount_minor) 
          FROM loan_repayments lr 
          WHERE lr.loan_id = l.id AND lr.status = 'posted'
        ), 0) AS total_repaid_minor
      FROM loans l
      LEFT JOIN people p ON l.person_id = p.id
      LEFT JOIN accounts a ON l.account_id = a.id
      WHERE ${whereParts.join(' AND ')}
      ORDER BY l.loan_date DESC, l.created_at DESC
    ''';

    final rows = await db.rawQuery(sql, whereArgs);
    return rows.map((r) => Loan.fromMap(r)).toList();
  }

  /// Retrieves a specific loan by [loanId].
  Future<Loan?> getLoanById(String userId, String loanId) async {
    final list = await getLoans(userId);
    return list.where((l) => l.id == loanId).firstOrNull;
  }

  /// Retrieves all repayment records for a loan.
  Future<List<LoanRepayment>> getRepaymentsForLoan(
    String userId,
    String loanId,
  ) async {
    final db = _dbService.getActiveDatabase(userId);
    final sql = '''
      SELECT 
        lr.*,
        a.name AS account_name
      FROM loan_repayments lr
      LEFT JOIN accounts a ON lr.account_id = a.id
      WHERE lr.user_id = ? AND lr.loan_id = ?
      ORDER BY lr.repayment_date DESC, lr.created_at DESC
    ''';

    final rows = await db.rawQuery(sql, [userId, loanId]);
    return rows.map((r) => LoanRepayment.fromMap(r)).toList();
  }
}

