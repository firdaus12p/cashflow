// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

import 'test_support/db_test_harness.dart';

void main() {
  setUpAll(() async {
    await initializeSharedTestDatabase();
  });

  setUp(() async {
    await resetSharedTestDatabase();
  });

  tearDownAll(() async {
    await disposeSharedTestDatabase();
  });

  final now = DateTime(2026);

  Debt debt0({
    int? id,
    String type = 'debt',
    String person = 'Budi',
    double principal = 500000,
    double remaining = 500000,
    String mode = 'note',
    String status = 'active',
    DateTime? due,
  }) =>
      Debt(
        id: id,
        type: type,
        personName: person,
        principalAmount: principal,
        remainingAmount: remaining,
        borrowedDate: now,
        dueDate: due,
        recordingMode: mode,
        status: status,
        createdDate: now,
        updatedDate: now,
      );

  // ---------------------------------------------------------------------------
  // CRUD Debt — DB level, akan GREEN karena CRUD sudah ada dari Phase 2
  // ---------------------------------------------------------------------------

  group('CRUD Debt — database level', () {
    test('insertDebt lalu getDebts mengembalikan record baru', () async {
      final db = DatabaseHelper();
      await db.database;

      await db.insertDebt(debt0(person: 'Andi'));

      final debts = await db.getDebts();
      expect(debts.any((d) => d.personName == 'Andi'), isTrue);
    });

    test('getDebtById mengembalikan debt yang benar', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(debt0(person: 'Budi'));
      final found = await db.getDebtById(id);

      expect(found, isNotNull);
      expect(found!.personName, 'Budi');
    });

    test('updateDebt menyimpan perubahan', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(debt0(person: 'Lama'));
      final old = (await db.getDebtById(id))!;
      await db.updateDebt(Debt(
        id: old.id,
        type: old.type,
        personName: 'Baru',
        principalAmount: old.principalAmount,
        remainingAmount: old.remainingAmount,
        borrowedDate: old.borrowedDate,
        recordingMode: old.recordingMode,
        createdDate: old.createdDate,
        updatedDate: DateTime.now(),
      ));

      final updated = (await db.getDebtById(id))!;
      expect(updated.personName, 'Baru');
    });

    test('deleteDebt menghapus record', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(debt0());
      await db.deleteDebt(id);

      expect(await db.getDebtById(id), isNull);
    });

    test('deleteDebt juga menghapus pembayaran note-only turunannya', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(debt0(mode: 'note'));
      await db.recordDebtPayment(
        debtId: id,
        amount: 50000,
        paymentDate: now,
        recordingMode: 'note',
      );

      await db.deleteDebt(id);

      expect(await db.getDebtById(id), isNull);
      expect(await db.getDebtPaymentsByDebt(id), isEmpty);
    });

    test('deleteDebt menghapus debt balance tanpa membalik transaksi',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Cash Baru',
        createdDate: now,
        updatedDate: now,
      ));
      final bucketId = await db.insertFinancialBucket(FinancialBucket(
        name: 'Dana',
        allocationPercentage: 100,
        currentBalance: 0,
        createdDate: now,
        updatedDate: now,
      ));
      final bucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);

      await db.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Hutang',
        description: 'Hutang dari Budi',
        date: now,
        walletName: 'Cash Baru',
        subsetBuckets: [bucket],
        walletId: walletId,
      );

      final transactionsBefore = await db.getTransactions();
      expect(transactionsBefore.isNotEmpty, isTrue);

      final id = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: walletId,
        bucketId: bucketId,
        createdDate: now,
        updatedDate: now,
      ));

      await db.deleteDebt(id);

      // debt record removed
      expect(await db.getDebtById(id), isNull);
      // transactions untouched — riwayat & saldo tetap
      final transactionsAfter = await db.getTransactions();
      expect(transactionsAfter.length, transactionsBefore.length);
    });

    test('insertDebtPayment + getDebtPaymentsByDebt mengembalikan cicilan',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final debtId = await db.insertDebt(debt0());
      await db.insertDebtPayment(DebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: now,
        recordingMode: 'note',
        createdDate: now,
      ));

      final payments = await db.getDebtPaymentsByDebt(debtId);
      expect(payments.length, 1);
      expect(payments.first.amount, 100000.0);
    });

    test(
        'insertDebt balance mode dompet-only tetap butuh transaksi saldo terpisah',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Cash Baru',
        createdDate: now,
        updatedDate: now,
      ));

      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 200000,
        category: 'Hutang',
        description: 'Hutang dari Budi',
        date: now,
        wallet: 'Cash Baru',
        walletId: walletId,
        walletNameSnapshot: 'Cash Baru',
      ));

      final id = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: walletId,
        createdDate: now,
        updatedDate: now,
      ));

      final debt = await db.getDebtById(id);
      final transactions = await db.getTransactions();

      expect(debt, isNotNull);
      expect(
        transactions.where((tx) => tx.description == 'Hutang dari Budi').length,
        1,
      );
    });

    test('insertDebt balance mode dompet-only tidak menyimpan bucketId',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Wallet Tes',
        createdDate: now,
        updatedDate: now,
      ));

      final id = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: walletId,
        createdDate: now,
        updatedDate: now,
      ));

      final debt = await db.getDebtById(id);
      expect(debt?.bucketId, isNull);
    });

    test('create debt balance-mode dompet-only harus atomik', () async {
      final db = DatabaseHelper();
      await db.database;

      final before = await db.getTransactions();

      await expectLater(
        db.createDebtWithBalanceEffect(
          debt: Debt(
            type: 'debt',
            personName: 'Budi',
            principalAmount: 200000,
            remainingAmount: 200000,
            borrowedDate: now,
            recordingMode: 'balance',
            walletId: null,
            createdDate: now,
            updatedDate: now,
          ),
          walletName: '',
          bucketSystemEnabled: false,
        ),
        throwsA(isA<StateError>()),
      );

      final after = await db.getTransactions();
      expect(after.length, before.length);
    });
  });

  // ---------------------------------------------------------------------------
  // recordDebtPayment — atomic helper
  // gap: belum ada — ditambahkan di Task 6.4
  // ---------------------------------------------------------------------------

  group('recordDebtPayment — atomic', () {
    test('mengurangi remainingAmount sesuai jumlah cicilan', () async {
      final db = DatabaseHelper();
      await db.database;

      final id =
          await db.insertDebt(debt0(principal: 500000, remaining: 500000));

      // gap: method belum ada
      await db.recordDebtPayment(
        debtId: id,
        amount: 150000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.remainingAmount, closeTo(350000, 0.01));
    });

    test('mengubah status menjadi settled saat lunas', () async {
      final db = DatabaseHelper();
      await db.database;

      final id =
          await db.insertDebt(debt0(principal: 200000, remaining: 200000));
      await db.recordDebtPayment(
        debtId: id,
        amount: 200000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.status, 'settled');
      expect(updated.remainingAmount, closeTo(0, 0.01));
    });

    test('cicilan dicatat di tabel debt_payments', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(debt0());
      await db.recordDebtPayment(
        debtId: id,
        amount: 50000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final payments = await db.getDebtPaymentsByDebt(id);
      expect(payments.length, 1);
      expect(payments.first.amount, 50000.0);
    });

    test('menolak cicilan yang melebihi sisa kewajiban', () async {
      final db = DatabaseHelper();
      await db.database;

      final id =
          await db.insertDebt(debt0(principal: 200000, remaining: 50000));

      await expectLater(
        db.recordDebtPayment(
          debtId: id,
          amount: 60000,
          paymentDate: now,
          recordingMode: 'note',
        ),
        throwsA(isA<RangeError>()),
      );

      final updated = (await db.getDebtById(id))!;
      final payments = await db.getDebtPaymentsByDebt(id);
      expect(updated.remainingAmount, closeTo(50000, 0.01));
      expect(updated.status, 'active');
      expect(payments, isEmpty);
    });
  });
}
