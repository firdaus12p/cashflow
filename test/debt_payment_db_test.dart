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

  Future<int> insertDebt(DatabaseHelper db,
      {String type = 'debt',
      double principal = 500000,
      double remaining = 500000,
      String mode = 'note'}) async {
    return await db.insertDebt(Debt(
      type: type,
      personName: 'Test',
      principalAmount: principal,
      remainingAmount: remaining,
      borrowedDate: now,
      recordingMode: mode,
      createdDate: now,
      updatedDate: now,
    ));
  }

  Future<FinancialBucket> insertBucket(
    DatabaseHelper db, {
    required String name,
    double pct = 100,
    double balance = 500000,
    int? walletId,
  }) async {
    final id = await db.insertFinancialBucket(FinancialBucket(
      name: name,
      walletId: walletId,
      allocationPercentage: pct,
      currentBalance: 0,
      createdDate: now,
      updatedDate: now,
    ));
    var bucket = (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
    if (balance > 0) {
      final wallets = await db.getActiveWallets();
      final wallet = wallets.firstWhere(
        (candidate) => candidate.id == walletId,
        orElse: () => wallets.first,
      );
      await db.saveIncomeWithAllocations(
        amount: balance,
        category: 'Seed',
        description: 'Seed $name',
        date: now,
        walletName: wallet.name,
        walletId: wallet.id,
        subsetBuckets: [bucket],
      );
      bucket = (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
    }
    return bucket;
  }

  group('BR-05 — mode pencatatan cicilan', () {
    test(
        'cicilan mode note mengurangi remainingAmount tanpa mengubah saldo pos',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await insertBucket(db, name: 'Dana', balance: 300000);
      final debtId = await insertDebt(db, mode: 'note');

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(debtId))!;
      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);

      expect(updated.remainingAmount, closeTo(400000, 0.01));
      expect(updatedBucket.currentBalance, closeTo(300000, 0.01));
    });

    test('cicilan mode balance mengubah saldo pos sumber untuk hutang',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await insertBucket(db, name: 'Harian', balance: 500000);
      final debtId = await insertDebt(db, type: 'debt', mode: 'balance');

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 150000,
        paymentDate: now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      final updated = (await db.getDebtById(debtId))!;
      expect(updated.remainingAmount, closeTo(350000, 0.01));

      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);
      expect(updatedBucket.currentBalance, closeTo(350000, 0.01));
    });

    test('cicilan piutang mode balance menambah saldo pos tujuan', () async {
      final db = DatabaseHelper();
      await db.database;

      final bucket = await insertBucket(db, name: 'Tabungan', balance: 100000);
      final receivableId =
          await insertDebt(db, type: 'receivable', mode: 'balance');

      await db.recordDebtPayment(
        debtId: receivableId,
        amount: 80000,
        paymentDate: now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      final updated = (await db.getDebtById(receivableId))!;
      expect(updated.remainingAmount, closeTo(420000, 0.01));

      final updatedBucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);
      expect(updatedBucket.currentBalance, closeTo(180000, 0.01));
    });
  });

  group('Status dan progres setelah cicilan', () {
    test('status berubah settled bila remainingAmount menjadi 0', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await insertDebt(db, principal: 200000, remaining: 200000);

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

    test('cicilan menerima sisa pecahan yang setara unit rupiah lalu settle',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await insertDebt(db, principal: 2537214, remaining: 2537213.6);

      await db.recordDebtPayment(
        debtId: id,
        amount: 2537214,
        paymentDate: now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.status, 'settled');
      expect(rupiahUnits(updated.remainingAmount), 0);
    });

    test('status tetap active bila masih ada sisa', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await insertDebt(db, principal: 500000, remaining: 500000);
      await db.recordDebtPayment(
        debtId: id,
        amount: 100000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final updated = (await db.getDebtById(id))!;
      expect(updated.status, 'active');
      expect(updated.remainingAmount, closeTo(400000, 0.01));
    });

    test('progressFraction benar setelah beberapa cicilan', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await insertDebt(db, principal: 1000000, remaining: 1000000);

      await db.recordDebtPayment(
          debtId: id, amount: 250000, paymentDate: now, recordingMode: 'note');
      await db.recordDebtPayment(
          debtId: id, amount: 250000, paymentDate: now, recordingMode: 'note');

      final updated = (await db.getDebtById(id))!;
      expect(updated.progressFraction, closeTo(0.5, 0.001));
    });

    test('riwayat cicilan tersimpan untuk setiap pembayaran', () async {
      final db = DatabaseHelper();
      await db.database;

      final id = await insertDebt(db);
      await db.recordDebtPayment(
          debtId: id, amount: 100000, paymentDate: now, recordingMode: 'note');
      await db.recordDebtPayment(
          debtId: id, amount: 50000, paymentDate: now, recordingMode: 'note');

      final payments = await db.getDebtPaymentsByDebt(id);
      expect(payments.length, 2);
    });
  });

  group('BR-13 — saldo pos konsisten setelah cicilan', () {
    test('total saldo pos tetap sama setelah cicilan note', () async {
      final db = DatabaseHelper();
      await db.database;

      final a = await insertBucket(db, name: 'A', pct: 60, balance: 0);
      final b = await insertBucket(db, name: 'B', pct: 40, balance: 0);
      final cash = (await db.getActiveWallets()).firstWhere(
        (wallet) => wallet.id == a.walletId,
      );
      await db.saveIncomeWithAllocations(
        amount: 1000000,
        category: 'Seed',
        description: 'Seed A+B',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        subsetBuckets: [a, b],
      );
      final debtId = await insertDebt(db, mode: 'note');

      final bucketsBefore = await db.getFinancialBuckets();
      final totalBefore =
          bucketsBefore.fold(0.0, (sum, bucket) => sum + bucket.currentBalance);

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 200000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final buckets = await db.getFinancialBuckets();
      final totalAfter = buckets.fold(0.0, (s, b) => s + b.currentBalance);

      expect(totalAfter, closeTo(totalBefore, 0.01));
    });

    test('cicilan balance menurunkan wallet dari bucket yang dipilih',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final activeWallets = await db.getActiveWallets();
      final cashWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Cash');
      final bankWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Bank');

      final bankBucket = await insertBucket(
        db,
        name: 'Cicilan Bank',
        balance: 300000,
        walletId: bankWallet.id,
      );
      final debtId = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Andi',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: cashWallet.id,
        bucketId: bankBucket.id,
        createdDate: now,
        updatedDate: now,
      ));

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 50000,
        paymentDate: now,
        recordingMode: 'balance',
        walletId: cashWallet.id,
        affectedBucket: bankBucket,
        walletName: cashWallet.name,
      );

      final tx = (await db.getTransactions())
          .firstWhere((t) => t.description == 'Pembayaran hutang Andi');
      expect(tx.walletId, bankWallet.id);
      expect(tx.wallet, 'Bank');
    });

    test('cicilan debt mode balance ditolak bila saldo pos atau dompet kurang',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final wallet = (await db.getActiveWallets())
          .firstWhere((activeWallet) => activeWallet.name == 'Cash');
      final bucket = await insertBucket(
        db,
        name: 'Cicilan Tipis',
        balance: 30000,
        walletId: wallet.id,
      );
      final debtId = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 100000,
        remainingAmount: 100000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: wallet.id,
        bucketId: bucket.id,
        createdDate: now,
        updatedDate: now,
      ));

      await expectLater(
        db.recordDebtPayment(
          debtId: debtId,
          amount: 50000,
          paymentDate: now,
          recordingMode: 'balance',
          walletId: wallet.id,
          bucketId: bucket.id,
          affectedBucket: bucket,
          walletName: wallet.name,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );

      final updatedDebt = (await db.getDebtById(debtId))!;
      final updatedBucket = (await db.getFinancialBuckets())
          .firstWhere((current) => current.id == bucket.id);
      expect(updatedDebt.remainingAmount, closeTo(100000, 0.01));
      expect(updatedBucket.currentBalance, closeTo(30000, 0.01));
    });
  });
}
