// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:cashflow/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.overrideDatabasePath(':memory:');
  });

  tearDown(() async {
    await DatabaseHelper.closeDatabase();
  });

  final _now = DateTime(2026);

  Debt _debt({
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
        borrowedDate: _now,
        dueDate: due,
        recordingMode: mode,
        status: status,
        createdDate: _now,
        updatedDate: _now,
      );

  // ---------------------------------------------------------------------------
  // Model computed properties — pure unit tests, zero DB
  // gap: isOverdue dan progressFraction belum ada di model — Task 6.2
  // ---------------------------------------------------------------------------

  group('Debt model computed properties', () {
    test('isOverdue true bila dueDate sudah lewat dan masih active', () {
      final d = _debt(
        due: DateTime(2025, 1, 1), // lewat
        remaining: 100000,
        status: 'active',
      );
      expect(d.isOverdue, isTrue);
    });

    test('isOverdue false bila sudah settled', () {
      final d = _debt(
        due: DateTime(2025, 1, 1),
        remaining: 0,
        status: 'settled',
      );
      expect(d.isOverdue, isFalse);
    });

    test('isOverdue false bila tidak ada dueDate', () {
      expect(_debt().isOverdue, isFalse);
    });

    test('isOverdue false bila dueDate belum lewat', () {
      final d = _debt(due: DateTime(2099, 12, 31), remaining: 100000);
      expect(d.isOverdue, isFalse);
    });

    test('progressFraction 0 saat baru dibuat', () {
      final d = _debt(principal: 500000, remaining: 500000);
      expect(d.progressFraction, closeTo(0.0, 0.001));
    });

    test('progressFraction 0.6 saat 60% sudah dibayar', () {
      final d = _debt(principal: 500000, remaining: 200000);
      expect(d.progressFraction, closeTo(0.6, 0.001));
    });

    test('progressFraction 1.0 saat lunas', () {
      final d = _debt(principal: 500000, remaining: 0);
      expect(d.progressFraction, closeTo(1.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // CRUD Debt — DB level, akan GREEN karena CRUD sudah ada dari Phase 2
  // ---------------------------------------------------------------------------

  group('CRUD Debt — database level', () {
    test('insertDebt lalu getDebts mengembalikan record baru', () async {
      final db = DatabaseHelper();
      await db.database;

      await db.insertDebt(_debt(person: 'Andi'));

      final debts = await db.getDebts();
      expect(debts.any((d) => d.personName == 'Andi'), isTrue);
    });

    test('getDebtById mengembalikan debt yang benar', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(_debt(person: 'Budi'));
      final found = await db.getDebtById(id);

      expect(found, isNotNull);
      expect(found!.personName, 'Budi');
    });

    test('updateDebt menyimpan perubahan', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(_debt(person: 'Lama'));
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

      final id = await db.insertDebt(_debt());
      await db.deleteDebt(id);

      expect(await db.getDebtById(id), isNull);
    });

    test('deleteDebt juga menghapus pembayaran note-only turunannya', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(_debt(mode: 'note'));
      await db.recordDebtPayment(
        debtId: id,
        amount: 50000,
        paymentDate: _now,
        recordingMode: 'note',
      );

      await db.deleteDebt(id);

      expect(await db.getDebtById(id), isNull);
      expect(await db.getDebtPaymentsByDebt(id), isEmpty);
    });

    test('deleteDebt menolak debt balance yang sudah memengaruhi saldo',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Cash Baru',
        createdDate: _now,
        updatedDate: _now,
      ));
      final bucketId = await db.insertFinancialBucket(FinancialBucket(
        name: 'Dana',
        allocationPercentage: 100,
        currentBalance: 0,
        createdDate: _now,
        updatedDate: _now,
      ));
      final bucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);

      await db.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Hutang',
        description: 'Hutang dari Budi',
        date: _now,
        walletName: 'Cash Baru',
        subsetBuckets: [bucket],
        walletId: walletId,
      );

      final id = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: _now,
        recordingMode: 'balance',
        walletId: walletId,
        bucketId: bucketId,
        createdDate: _now,
        updatedDate: _now,
      ));

      await expectLater(db.deleteDebt(id), throwsA(isA<StateError>()));
      expect(await db.getDebtById(id), isNotNull);
    });

    test('insertDebtPayment + getDebtPaymentsByDebt mengembalikan cicilan',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final debtId = await db.insertDebt(_debt());
      await db.insertDebtPayment(DebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: _now,
        recordingMode: 'note',
        createdDate: _now,
      ));

      final payments = await db.getDebtPaymentsByDebt(debtId);
      expect(payments.length, 1);
      expect(payments.first.amount, 100000.0);
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
          await db.insertDebt(_debt(principal: 500000, remaining: 500000));

      // gap: method belum ada
      await db.recordDebtPayment(
        debtId: id,
        amount: 150000,
        paymentDate: _now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.remainingAmount, closeTo(350000, 0.01));
    });

    test('mengubah status menjadi settled saat lunas', () async {
      final db = DatabaseHelper();
      await db.database;

      final id =
          await db.insertDebt(_debt(principal: 200000, remaining: 200000));
      await db.recordDebtPayment(
        debtId: id,
        amount: 200000,
        paymentDate: _now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.status, 'settled');
      expect(updated.remainingAmount, closeTo(0, 0.01));
    });

    test('cicilan dicatat di tabel debt_payments', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await db.insertDebt(_debt());
      await db.recordDebtPayment(
        debtId: id,
        amount: 50000,
        paymentDate: _now,
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
          await db.insertDebt(_debt(principal: 200000, remaining: 50000));

      await expectLater(
        db.recordDebtPayment(
          debtId: id,
          amount: 60000,
          paymentDate: _now,
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
