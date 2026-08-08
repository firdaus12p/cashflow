// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:pinkycash_app/main.dart';

// Semua test di sini pakai test() bukan testWidgets() — DB-level tests.
// sqflite_ffi pakai real isolate, tidak bisa di-await di fake-async zone.

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

  Future<int> _insertDebt(DatabaseHelper db,
      {String type = 'debt',
      double principal = 500000,
      double remaining = 500000,
      String mode = 'note'}) async {
    return await db.insertDebt(Debt(
      type: type,
      personName: 'Test',
      principalAmount: principal,
      remainingAmount: remaining,
      borrowedDate: _now,
      recordingMode: mode,
      createdDate: _now,
      updatedDate: _now,
    ));
  }

  Future<FinancialBucket> _insertBucket(
    DatabaseHelper db, {
    required String name,
    double pct = 100,
    double balance = 500000,
  }) async {
    final id = await db.insertFinancialBucket(FinancialBucket(
      name: name,
      allocationPercentage: pct,
      currentBalance: balance,
      createdDate: _now,
      updatedDate: _now,
    ));
    return (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
  }

  // ---------------------------------------------------------------------------
  // BR-05: efek mode pada cicilan
  // ---------------------------------------------------------------------------

  group('BR-05 — mode pencatatan cicilan', () {
    test(
        'cicilan mode note mengurangi remainingAmount tanpa mengubah saldo pos',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await _insertBucket(db, name: 'Dana', balance: 300000);
      final debtId = await _insertDebt(db, mode: 'note');

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: _now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(debtId))!;
      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);

      expect(updated.remainingAmount, closeTo(400000, 0.01));
      // Saldo pos tidak berubah untuk mode note
      expect(updatedBucket.currentBalance, closeTo(300000, 0.01));
    });

    test('cicilan mode balance mengubah saldo pos sumber untuk hutang',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await _insertBucket(db, name: 'Harian', balance: 500000);
      final debtId = await _insertDebt(db, type: 'debt', mode: 'balance');

      // gap: recordDebtPayment dengan affectedBucket belum menerapkan side effect
      // — Task 6.4 mengimplementasikan ini
      await db.recordDebtPayment(
        debtId: debtId,
        amount: 150000,
        paymentDate: _now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      final updated = (await db.getDebtById(debtId))!;
      expect(updated.remainingAmount, closeTo(350000, 0.01));

      // Setelah Task 6.4, saldo pos juga berubah:
      // debt payment mode balance = expense (uang keluar dari pos)
      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);
      expect(updatedBucket.currentBalance, closeTo(350000, 0.01));
    });

    test('cicilan piutang mode balance menambah saldo pos tujuan', () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await _insertBucket(db, name: 'Tabungan', balance: 100000);
      final receivableId =
          await _insertDebt(db, type: 'receivable', mode: 'balance');

      await db.recordDebtPayment(
        debtId: receivableId,
        amount: 80000,
        paymentDate: _now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      final updated = (await db.getDebtById(receivableId))!;
      expect(updated.remainingAmount, closeTo(420000, 0.01));

      // receivable payment mode balance = income (uang masuk ke pos)
      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);
      expect(updatedBucket.currentBalance, closeTo(180000, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // Status dan progres setelah cicilan
  // ---------------------------------------------------------------------------

  group('Status dan progres setelah cicilan', () {
    test('status berubah settled bila remainingAmount menjadi 0', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await _insertDebt(db, principal: 200000, remaining: 200000);

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

    test('status tetap active bila masih ada sisa', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await _insertDebt(db, principal: 500000, remaining: 500000);
      await db.recordDebtPayment(
        debtId: id,
        amount: 100000,
        paymentDate: _now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.status, 'active');
      expect(updated.remainingAmount, closeTo(400000, 0.01));
    });

    test('progressFraction benar setelah beberapa cicilan', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await _insertDebt(db, principal: 1000000, remaining: 1000000);

      await db.recordDebtPayment(
          debtId: id, amount: 250000, paymentDate: _now, recordingMode: 'note');
      await db.recordDebtPayment(
          debtId: id, amount: 250000, paymentDate: _now, recordingMode: 'note');

      final updated = (await db.getDebtById(id))!;
      expect(updated.progressFraction, closeTo(0.5, 0.001));
    });

    test('riwayat cicilan tersimpan untuk setiap pembayaran', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await _insertDebt(db);
      await db.recordDebtPayment(
          debtId: id, amount: 100000, paymentDate: _now, recordingMode: 'note');
      await db.recordDebtPayment(
          debtId: id, amount: 50000, paymentDate: _now, recordingMode: 'note');

      final payments = await db.getDebtPaymentsByDebt(id);
      expect(payments.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // BR-13: konsistensi saldo saat cicilan memengaruhi pos
  // ---------------------------------------------------------------------------

  group('BR-13 — saldo pos konsisten setelah cicilan', () {
    test('total saldo pos tetap sama setelah cicilan note', () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await _insertBucket(db, name: 'A', pct: 60, balance: 600000);
      final b2 = await _insertBucket(db, name: 'B', pct: 40, balance: 400000);
      final debtId = await _insertDebt(db, mode: 'note');

      final totalBefore = b1.currentBalance + b2.currentBalance; // 1.000.000

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 200000,
        paymentDate: _now,
        recordingMode: 'note', // catatan saja → tidak mengubah pos
      );

      final buckets = await db.getFinancialBuckets();
      final totalAfter = buckets.fold(0.0, (s, b) => s + b.currentBalance);

      expect(totalAfter, closeTo(totalBefore, 0.01));
    });
  });
}
