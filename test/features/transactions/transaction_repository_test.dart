import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/features/accounts/data/account_repository.dart';
import 'package:hisab_pro/features/transactions/data/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 3: Accounts & Transaction Ledger Engine', () {
    late Database db;
    late DatabaseService dbService;
    late AccountRepository accountRepo;
    late TransactionRepository transactionRepo;
    const userId = 'test_user_p3';

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      // Create essential test tables
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
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          color_hex TEXT,
          icon_key TEXT,
          is_default INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          category_id TEXT,
          person_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          payment_method TEXT,
          transaction_date INTEGER NOT NULL,
          transaction_time INTEGER,
          notes TEXT,
          attachment_id TEXT,
          status TEXT NOT NULL DEFAULT 'posted',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE transfers (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          from_account_id TEXT NOT NULL,
          to_account_id TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          transfer_date INTEGER NOT NULL,
          note TEXT,
          status TEXT NOT NULL DEFAULT 'posted',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE loans (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          loan_type TEXT NOT NULL,
          amount_minor INTEGER NOT NULL
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
      transactionRepo = TransactionRepository(databaseService: dbService);
    });

    tearDown(() async {
      await db.close();
    });

    test('Account creation sets opening and current balance', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'Meezan Bank',
        accountType: 'bank',
        openingBalanceMinor: 5000000, // Rs. 50,000
      );

      expect(acc.name, 'Meezan Bank');
      expect(acc.currentBalanceMinor, 5000000);

      final fetched = await accountRepo.getAccountById(userId, acc.id);
      expect(fetched?.currentBalanceMinor, 5000000);
    });

    test('Income transaction increases account balance atomically', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'Cash',
        accountType: 'cash',
        openingBalanceMinor: 1000000, // Rs. 10,000
      );

      await transactionRepo.createTransaction(
        userId: userId,
        accountId: acc.id,
        type: 'income',
        title: 'Salary Bonus',
        amountMinor: 500000, // Rs. 5,000
        transactionDate: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedAcc = await accountRepo.getAccountById(userId, acc.id);
      expect(updatedAcc?.currentBalanceMinor, 1500000); // Rs. 15,000

      final txs = await transactionRepo.getTransactions(userId, type: 'income');
      expect(txs.length, 1);
      expect(txs.first.title, 'Salary Bonus');
      expect(txs.first.isIncome, isTrue);
    });

    test('Expense transaction decreases account balance atomically', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'Wallet',
        accountType: 'wallet',
        openingBalanceMinor: 500000, // Rs. 5,000
      );

      await transactionRepo.createTransaction(
        userId: userId,
        accountId: acc.id,
        type: 'expense',
        title: 'Dinner with friends',
        amountMinor: 120000, // Rs. 1,200
        transactionDate: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedAcc = await accountRepo.getAccountById(userId, acc.id);
      expect(updatedAcc?.currentBalanceMinor, 380000); // Rs. 3,800
    });

    test('Account transfer moves money atomically without affecting income/expense', () async {
      final bank = await accountRepo.createAccount(
        userId: userId,
        name: 'HBL',
        accountType: 'bank',
        openingBalanceMinor: 2000000, // Rs. 20,000
      );
      final cash = await accountRepo.createAccount(
        userId: userId,
        name: 'Physical Cash',
        accountType: 'cash',
        openingBalanceMinor: 100000, // Rs. 1,000
      );

      await transactionRepo.createTransfer(
        userId: userId,
        fromAccountId: bank.id,
        toAccountId: cash.id,
        amountMinor: 500000, // Rs. 5,000
        transferDate: DateTime.now().millisecondsSinceEpoch,
        note: 'ATM withdrawal',
      );

      final updatedBank = await accountRepo.getAccountById(userId, bank.id);
      final updatedCash = await accountRepo.getAccountById(userId, cash.id);

      expect(updatedBank?.currentBalanceMinor, 1500000); // 20k - 5k = 15k
      expect(updatedCash?.currentBalanceMinor, 600000); // 1k + 5k = 6k

      // Transfers must NOT be counted in income or expense transactions
      final incomeTxs = await transactionRepo.getTransactions(userId, type: 'income');
      final expenseTxs = await transactionRepo.getTransactions(userId, type: 'expense');
      expect(incomeTxs, isEmpty);
      expect(expenseTxs, isEmpty);

      final transfers = await transactionRepo.getTransfers(userId);
      expect(transfers.length, 1);
      expect(transfers.first.fromAccountName, 'HBL');
      expect(transfers.first.toAccountName, 'Physical Cash');
    });

    test('Deleting a transaction reverses account balance effect', () async {
      final acc = await accountRepo.createAccount(
        userId: userId,
        name: 'General',
        accountType: 'cash',
        openingBalanceMinor: 100000, // Rs. 1,000
      );

      final tx = await transactionRepo.createTransaction(
        userId: userId,
        accountId: acc.id,
        type: 'expense',
        title: 'Accidental entry',
        amountMinor: 40000, // Rs. 400
        transactionDate: DateTime.now().millisecondsSinceEpoch,
      );

      expect((await accountRepo.getAccountById(userId, acc.id))?.currentBalanceMinor, 60000);

      // Now delete transaction
      await transactionRepo.deleteTransaction(userId: userId, transactionId: tx.id);

      // Balance must revert back to Rs. 1,000
      final revertedAcc = await accountRepo.getAccountById(userId, acc.id);
      expect(revertedAcc?.currentBalanceMinor, 100000);

      final allTxs = await transactionRepo.getTransactions(userId);
      expect(allTxs, isEmpty);
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

