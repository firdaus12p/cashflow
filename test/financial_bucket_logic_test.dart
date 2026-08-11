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

  // ---------------------------------------------------------------------------
  // validateBucketPercentages — BR-08
  // gap: fungsi belum ada — ditambahkan di Task 5.2
  // ---------------------------------------------------------------------------

  final _now = DateTime(2026);

  // ---------------------------------------------------------------------------
  // executeBucketTransfer — BR-12: transfer tidak mengubah total saldo
  // Pakai test() bukan testWidgets() karena ini DB-level, bukan UI.
  // ---------------------------------------------------------------------------

  group('executeBucketTransfer — BR-12', () {
    test('transfer tidak mengubah total saldo keseluruhan', () async {
      final db = DatabaseHelper();
      await db.database;

      // Insert dua pos dengan saldo awal
      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Pos A',
        allocationPercentage: 60,
        currentBalance: 100,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Pos B',
        allocationPercentage: 40,
        currentBalance: 50,
        createdDate: _now,
        updatedDate: _now,
      ));

      final totalBefore = 150.0;

      // gap: DatabaseHelper.executeBucketTransfer belum ada — Task 5.2
      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 30,
        transferDate: _now,
      );

      final buckets = await db.getFinancialBuckets();
      final totalAfter = buckets.fold(0.0, (s, b) => s + b.currentBalance);

      expect(totalAfter, closeTo(totalBefore, 0.01));
    });

    test('saldo pos sumber berkurang dan pos tujuan bertambah', () async {
      final db = DatabaseHelper();
      await db.database;

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Sumber',
        allocationPercentage: 70,
        currentBalance: 200,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tujuan',
        allocationPercentage: 30,
        currentBalance: 100,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 50,
        transferDate: _now,
      );

      final buckets = await db.getFinancialBuckets();
      final a = buckets.firstWhere((b) => b.id == idA);
      final b = buckets.firstWhere((b) => b.id == idB);

      expect(a.currentBalance, closeTo(150, 0.01));
      expect(b.currentBalance, closeTo(150, 0.01));
    });

    test('transfer dicatat di tabel bucket_transfers', () async {
      final db = DatabaseHelper();
      await db.database;

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'A',
        allocationPercentage: 100,
        currentBalance: 500,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'B',
        allocationPercentage: 0,
        currentBalance: 0,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 100,
        transferDate: _now,
      );

      final transfers = await db.getBucketTransfers();
      expect(transfers.length, 1);
      expect(transfers.first.amount, 100.0);
      expect(transfers.first.fromBucketId, idA);
      expect(transfers.first.toBucketId, idB);
    });

    test(
        'transfer lintas dompet mencatat snapshot wallet dan mutasi wallet internal',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final activeWallets = await db.getActiveWallets();
      final cashWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Cash');
      final bankWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Bank');

      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Saldo awal Cash',
        date: _now,
        wallet: 'Cash',
        walletId: 1,
        walletNameSnapshot: 'Cash',
      ));
      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 100000,
        category: 'Gaji',
        description: 'Saldo awal Bank',
        date: _now,
        wallet: 'Bank',
        walletId: 2,
        walletNameSnapshot: 'Bank',
      ));

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Sumber Cash',
        walletId: cashWallet.id,
        allocationPercentage: 100,
        currentBalance: 500000,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tujuan Bank',
        walletId: bankWallet.id,
        allocationPercentage: 100,
        currentBalance: 100000,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 100000,
        transferDate: _now,
      );

      final transfers = await db.getBucketTransfers();
      final txs = await db.getTransactions();
      final cashBalance = calculateBalanceForWallet(
        txs,
        selectedWallet: 'Cash',
      );
      final bankBalance = calculateBalanceForWallet(
        txs,
        selectedWallet: 'Bank',
      );

      expect(transfers.single.fromWalletIdSnapshot, cashWallet.id);
      expect(transfers.single.toWalletIdSnapshot, bankWallet.id);
      expect(cashBalance, closeTo(400000, 0.01));
      expect(bankBalance, closeTo(200000, 0.01));
    });
  });
}
