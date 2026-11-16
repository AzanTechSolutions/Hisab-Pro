import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/errors/failure.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/features/people/domain/person.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing people/contacts and calculating person-wise loan exposures.
class PeopleRepository {
  PeopleRepository({required DatabaseService databaseService})
      : _dbService = databaseService;

  final DatabaseService _dbService;
  final _uuid = const Uuid();

  /// Retrieves all people for [userId] along with their calculated loan totals.
  Future<List<Person>> getPeople(String userId, {String? query}) async {
    final db = _dbService.getActiveDatabase(userId);

    String whereSql = 'p.user_id = ?';
    final whereArgs = <dynamic>[userId];

    if (query != null && query.trim().isNotEmpty) {
      whereSql += ' AND (p.full_name LIKE ? OR p.phone_number LIKE ?)';
      final term = '%${query.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final sql = '''
      SELECT 
        p.*,
        COALESCE((
          SELECT SUM(l.amount_minor) 
          FROM loans l 
          WHERE l.person_id = p.id AND l.user_id = p.user_id AND l.loan_type = 'loan_given'
        ), 0) AS total_lent_minor,
        COALESCE((
          SELECT SUM(l.amount_minor) 
          FROM loans l 
          WHERE l.person_id = p.id AND l.user_id = p.user_id AND l.loan_type = 'loan_taken'
        ), 0) AS total_borrowed_minor,
        COALESCE((
          SELECT SUM(l.amount_minor) - COALESCE((
            SELECT SUM(lr.amount_minor) 
            FROM loan_repayments lr 
            WHERE lr.loan_id = l.id AND lr.status = 'posted'
          ), 0)
          FROM loans l
          WHERE l.person_id = p.id AND l.user_id = p.user_id AND l.loan_type = 'loan_given' AND l.status != 'paid' AND l.status != 'closed'
        ), 0) AS outstanding_receivable_minor,
        COALESCE((
          SELECT SUM(l.amount_minor) - COALESCE((
            SELECT SUM(lr.amount_minor) 
            FROM loan_repayments lr 
            WHERE lr.loan_id = l.id AND lr.status = 'posted'
          ), 0)
          FROM loans l
          WHERE l.person_id = p.id AND l.user_id = p.user_id AND l.loan_type = 'loan_taken' AND l.status != 'paid' AND l.status != 'closed'
        ), 0) AS outstanding_payable_minor
      FROM people p
      WHERE $whereSql
      ORDER BY p.full_name ASC
    ''';

    final rows = await db.rawQuery(sql, whereArgs);
    return rows.map((r) => Person.fromMap(r)).toList();
  }

  /// Retrieves a single person by [personId].
  Future<Person?> getPersonById(String userId, String personId) async {
    final people = await getPeople(userId);
    return people.where((p) => p.id == personId).firstOrNull;
  }

  /// Creates a new contact.
  Future<Person> createPerson({
    required String userId,
    required String fullName,
    String? phoneNumber,
    String? address,
    String? notes,
  }) async {
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure('Name cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final person = Person(
      id: _uuid.v4(),
      userId: userId,
      fullName: cleanName,
      phoneNumber: phoneNumber?.trim(),
      address: address?.trim(),
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('people', person.toMap());
    AppLogger.info('Created contact: ${person.fullName} for user $userId');
    return person;
  }

  /// Updates person details.
  Future<void> updatePerson({
    required String userId,
    required String personId,
    required String fullName,
    String? phoneNumber,
    String? address,
    String? notes,
  }) async {
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure('Name cannot be empty.');
    }

    final db = _dbService.getActiveDatabase(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'people',
      {
        'full_name': cleanName,
        'phone_number': phoneNumber?.trim(),
        'address': address?.trim(),
        'notes': notes?.trim(),
        'updated_at': now,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [personId, userId],
    );
  }

  /// Deletes a person only if no loans are associated with them.
  Future<void> deletePerson(String userId, String personId) async {
    final db = _dbService.getActiveDatabase(userId);

    final loanCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM loans WHERE user_id = ? AND person_id = ?',
      [userId, personId],
    )) ?? 0;

    if (loanCount > 0) {
      throw const ValidationFailure('Cannot delete contact with existing loan records.');
    }

    await db.delete(
      'people',
      where: 'id = ? AND user_id = ?',
      whereArgs: [personId, userId],
    );
  }
}

