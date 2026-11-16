import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/features/accounts/data/account_repository.dart';
import 'package:hisab_pro/features/loans/data/loan_repository.dart';
import 'package:hisab_pro/features/people/data/people_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 4: People & Loan (Receivable/Payable) Repayment Ledger', () {
    late Database db;
    late DatabaseService dbService;
    late AccountRepository accountRepo;
    late PeopleRepository peopleRepo;
    late LoanRepository loanRepo;
    const userId = 'test_user_p4';

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      // Create schema tables for test
      await db.execute('''
        CREATE TABLE accounts (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          account_type TEXT NOT NULL,
          currency TEXT NOT NULL DEFAULT 'PKR',
          opening_balance_minor INTEGER NOT NULL DEFAULT 0,
          current_balance_minor INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE people (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          full_name TEXT NOT NULL,
          phone_number TEXT,
          address TEXT,
          notes TEXT,
          profile_image_path TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE loans (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          person_id TEXT NOT NULL,
          loan_type TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          interest_rate_percent REAL NOT NULL DEFAULT 0,
          loan_date INTEGER NOT NULL,
          due_date INTEGER,
          description TEXT,
          notes TEXT,
          account_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE loan_repayments (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          loan_id TEXT NOT NULL,
          repayment_date INTEGER NOT NULL,
          amount_minor INTEGER NOT NULL,
          account_id TEXT NOT NULL,
          notes TEXT,
          payment_method TEXT,
          status TEXT NOT NULL DEFAULT 'posted',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE audit_events (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          event_category TEXT NOT NULL,
          entity_type TEXT,
          entity_id TEXT,
          metadata_json TEXT,
          created_at INTEGER NOT NULL
        );
      ''');

      dbService = _TestDatabaseService(db);
      accountRepo = AccountRepository(databaseService: dbService);
      peopleRepo = PeopleRepository(databaseService: dbService);
      loanRepo = LoanRepository(databaseService: dbService);
    });

    tearDown(() async {
      await db.close();
    });

    test('Giving a loan (loan_given) decreases account balance as an asset outflow', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'Meezan',
        accountType: 'bank',
        openingBalanceMinor: 10000000, // Rs. 100,000
      );

      final person = await peopleRepo.createPerson(
        userId: userId,
        fullName: 'Bilal Ahmed',
        phoneNumber: '03001234567',
      );

      final loan = await loanRepo.createLoan(
        userId: userId,
        personId: person.id,
        loanType: 'loan_given',
        amountMinor: 4000000, // Lent Rs. 40,000
        loanDate: DateTime.now().millisecondsSinceEpoch,
        accountId: acc.id,
      );

      expect(loan.isGiven, isTrue);
      expect(loan.amountMinor, 4000000);

      // Account balance must decrease from 100k to 60k
      final updatedAcc = await accountRepo.getAccountById(userId, acc.id);
      expect(updatedAcc?.currentBalanceMinor, 6000000);

      // Outstanding receivable must show Rs. 40,000
      final fetchedPerson = await peopleRepo.getPersonById(userId, person.id);
      expect(fetchedPerson?.totalLentMinor, 4000000);
      expect(fetchedPerson?.outstandingReceivableMinor, 4000000);
    });

    test('Partial repayment on loan_given increases account balance & updates status to partial', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'Cash',
        accountType: 'cash',
        openingBalanceMinor: 5000000, // Rs. 50,000
      );

      final person = await peopleRepo.createPerson(
        userId: userId,
        fullName: 'Hamza Khan',
      );

      final loan = await loanRepo.createLoan(
        userId: userId,
        personId: person.id,
        loanType: 'loan_given',
        amountMinor: 3000000, // Rs. 30,000 lent
        loanDate: DateTime.now().millisecondsSinceEpoch,
        accountId: acc.id,
      );

      expect((await accountRepo.getAccountById(userId, acc.id))?.currentBalanceMinor, 2000000); // 50k - 30k = 20k

      // Record partial repayment of Rs. 10,000
      await loanRepo.recordRepayment(
        userId: userId,
        loanId: loan.id,
        amountMinor: 1000000, // Rs. 10,000 repaid
        accountId: acc.id,
        repaymentDate: DateTime.now().millisecondsSinceEpoch,
      );

      // Account balance must increase from 20k to 30k
      expect((await accountRepo.getAccountById(userId, acc.id))?.currentBalanceMinor, 3000000);

      // Loan remaining balance must be Rs. 20,000 and status partial
      final updatedLoan = await loanRepo.getLoanById(userId, loan.id);
      expect(updatedLoan?.totalRepaidMinor, 1000000);
      expect(updatedLoan?.remainingBalanceMinor, 2000000);
      expect(updatedLoan?.status, 'partial');
      expect(updatedLoan?.isPaid, isFalse);
    });

    test('Full settlement updates status to paid and overpayment is rejected', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'General',
        accountType: 'cash',
        openingBalanceMinor: 2000000,
      );
      final person = await peopleRepo.createPerson(
        userId: userId,
        fullName: 'Usman Ali',
      );
      final loan = await loanRepo.createLoan(
        userId: userId,
        personId: person.id,
        loanType: 'loan_given',
        amountMinor: 1000000, // Rs. 10,000
        loanDate: DateTime.now().millisecondsSinceEpoch,
        accountId: acc.id,
      );

      // Overpayment check (repaying 15,000 when loan is 10,000)
      expect(
        () => loanRepo.recordRepayment(
          userId: userId,
          loanId: loan.id,
          amountMinor: 1500000,
          accountId: acc.id,
          repaymentDate: DateTime.now().millisecondsSinceEpoch,
        ),
        throwsA(isA<Exception>()),
      );

      // Settle exact 10,000
      await loanRepo.recordRepayment(
        userId: userId,
        loanId: loan.id,
        amountMinor: 1000000,
        accountId: acc.id,
        repaymentDate: DateTime.now().millisecondsSinceEpoch,
      );

      final settledLoan = await loanRepo.getLoanById(userId, loan.id);
      expect(settledLoan?.remainingBalanceMinor, 0);
      expect(settledLoan?.status, 'paid');
      expect(settledLoan?.isPaid, isTrue);
    });

    test('Taking a loan (loan_taken) increases account balance & repayment decreases it', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'HBL',
        accountType: 'bank',
        openingBalanceMinor: 500000, // Rs. 5,000
      );
      final lender = await peopleRepo.createPerson(
        userId: userId,
        fullName: 'Uncle Rashid',
      );

      // Borrow 50,000 PKR
      final loan = await loanRepo.createLoan(
        userId: userId,
        personId: lender.id,
        loanType: 'loan_taken',
        amountMinor: 5000000, // Rs. 50,000
        loanDate: DateTime.now().millisecondsSinceEpoch,
        accountId: acc.id,
      );

      // Balance increases from 5k to 55k
      expect((await accountRepo.getAccountById(userId, acc.id))?.currentBalanceMinor, 5500000);

      // Repay 20,000 PKR back to lender
      await loanRepo.recordRepayment(
        userId: userId,
        loanId: loan.id,
        amountMinor: 2000000,
        accountId: acc.id,
        repaymentDate: DateTime.now().millisecondsSinceEpoch,
      );

      // Balance decreases from 55k to 35k
      expect((await accountRepo.getAccountById(userId, acc.id))?.currentBalanceMinor, 3500000);

      final updatedLoan = await loanRepo.getLoanById(userId, loan.id);
      expect(updatedLoan?.remainingBalanceMinor, 3000000); // 30,000 remaining payable
    });
  });
}

class _TestDatabaseService extends DatabaseService {
  _TestDatabaseService(this.testDb);
  final Database testDb;

  @override
  Database getActiveDatabase(String profileId) => testDb;

  @override
  bool isProfileDatabaseOpen(String profileId) => true;
}

