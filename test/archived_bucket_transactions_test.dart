// Transactions that touched a bucket which was later removed from active use.
import 'package:cashflow/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final db = DatabaseHelper();
  final now = DateTime(2026, 9, 1);
  late Wallet cash;
  late Wallet bank;
  late FinancialBucket archived;
  late int expenseId;
  late int incomeId;

  setUpAll(initializeSharedTestDatabase);
  tearDownAll(disposeSharedTestDatabase);

  Future<FinancialBucket> reload(FinancialBucket bucket) async =>
      (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucket.id);

  Future<FinancialBucket> addBucket(String name, double pct, Wallet wallet) async {
    final id = await db.insertFinancialBucket(FinancialBucket(
      name: name,
      walletId: wallet.id,
      allocationPercentage: pct,
      createdDate: now,
      updatedDate: now,
    ));
    return (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
  }

  // Active bucket "Tabungan" ends with 160000 and "Jajan" is archived at 0.
  late FinancialBucket active;

  setUp(() async {
    await resetSharedTestDatabase();
    final wallets = await db.getActiveWallets();
    cash = wallets.firstWhere((w) => w.name == 'Cash');
    bank = wallets.firstWhere((w) => w.name == 'Bank');
    archived = await addBucket('Jajan', 50, cash);
    active = await addBucket('Tabungan', 50, cash);
    await db.setBucketSystemEnabled(true);
    incomeId = await db.saveIncomeWithAllocations(
      amount: 200000,
      category: 'Gaji',
      description: 'Gaji',
      date: now,
      walletName: cash.name,
      walletId: cash.id,
      subsetBuckets: [archived, active],
    );
    expenseId = await db.saveExpenseWithSource(
      amount: 40000,
      category: 'Makanan',
      description: 'Bakso',
      date: now,
      walletName: cash.name,
      walletId: cash.id,
      sourceBucket: await reload(archived),
    );
    await db.executeBucketTransfer(
      fromBucketId: archived.id!,
      toBucketId: active.id!,
      amount: 60000,
      transferDate: now,
    );
    await db.removeFinancialBucketFromActive(archived.id!);
    final current = await reload(active);
    await db.updateFinancialBucket(FinancialBucket(
      id: current.id,
      name: current.name,
      walletId: current.walletId,
      allocationPercentage: 100,
      currentBalance: current.currentBalance,
      createdDate: current.createdDate,
      updatedDate: now,
    ));
    expect((await reload(active)).currentBalance, 160000);
  });

  Future<double> activeBalance() async => (await reload(active)).currentBalance;

  Future<int> updateExpense({
    double amount = 40000,
    Map<int, int>? replacements,
    FinancialBucket? source,
    String description = 'Bakso',
  }) =>
      db.updateTransaction(
        transactionId: expenseId,
        type: 'expense',
        amount: amount,
        category: 'Makanan',
        description: description,
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        sourceBucket: source ?? active,
        bucketReplacements: replacements,
      );

  group('hapus transaksi dari pos yang sudah dihapus', () {
    test('tanpa pos pengganti: minta pengganti dan tidak mengubah apa pun',
        () async {
      await expectLater(
        db.deleteTransaction(expenseId),
        throwsA(isA<ArchivedBucketReplacementRequired>().having(
            (e) => e.buckets.map((b) => b.id).toList(),
            'bucket yang butuh pengganti',
            [archived.id])),
      );
      expect(await activeBalance(), 160000);
      expect((await db.getTransactions()).any((t) => t.id == expenseId), isTrue);
    });

    test('pengeluaran: uang kembali ke pos pengganti', () async {
      await db.deleteTransaction(expenseId,
          bucketReplacements: {archived.id!: active.id!});
      expect(await activeBalance(), 200000);
      expect((await db.getTransactions()).any((t) => t.id == expenseId), isFalse);
      expect((await reload(archived)).currentBalance, 0);
    });

    test('pemasukan: bagian pos lama dikurangkan dari pos pengganti', () async {
      await db.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Bonus',
        description: 'Bonus',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        subsetBuckets: [active],
      );
      expect(await activeBalance(), 360000);
      await db.deleteTransaction(incomeId,
          bucketReplacements: {archived.id!: active.id!});
      expect(await activeBalance(), 160000);
    });

    test('pos pengganti di dompet lain ditolak', () async {
      final other = await addBucket('Bank', 0, bank);
      await expectLater(
        db.deleteTransaction(expenseId,
            bucketReplacements: {archived.id!: other.id!}),
        throwsStateError,
      );
      expect(await activeBalance(), 160000);
    });

    test('pos pengganti yang sudah dihapus ditolak', () async {
      await expectLater(
        db.deleteTransaction(expenseId,
            bucketReplacements: {archived.id!: archived.id!}),
        throwsStateError,
      );
      expect(await activeBalance(), 160000);
    });
  });

  group('ubah nominal transaksi dari pos yang sudah dihapus', () {
    test('tanpa pos pengganti: minta pengganti', () async {
      await expectLater(
        updateExpense(amount: 30000),
        throwsA(isA<ArchivedBucketReplacementRequired>()),
      );
      expect(await activeBalance(), 160000);
    });

    test('dengan pos pengganti: selisih masuk ke pos pengganti', () async {
      await updateExpense(
          amount: 30000, replacements: {archived.id!: active.id!});
      expect(await activeBalance(), 170000);
      final allocation =
          (await db.getTransactionBucketAllocations(expenseId)).single;
      expect(allocation.bucketId, active.id);
      expect(allocation.allocatedAmount, 30000);
    });
  });

  group('ubah detail tanpa menyentuh uang', () {
    test('keterangan, kategori, dan tanggal bisa diubah; pos dan saldo tetap',
        () async {
      await db.updateTransactionDetails(
        transactionId: expenseId,
        category: 'Hiburan',
        description: 'Nonton',
        date: now.add(const Duration(days: 2)),
      );
      final tx = (await db.getTransactions()).firstWhere((t) => t.id == expenseId);
      expect(tx.description, 'Nonton');
      expect(tx.category, 'Hiburan');
      expect(tx.date, now.add(const Duration(days: 2)));
      expect(tx.amount, 40000);
      expect(await activeBalance(), 160000);
      final allocation =
          (await db.getTransactionBucketAllocations(expenseId)).single;
      expect(allocation.bucketId, archived.id);
    });

    test('transaksi hutang/piutang tetap tidak bisa diubah', () async {
      final debtId = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Andi',
        principalAmount: 10000,
        remainingAmount: 10000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: cash.id,
        bucketId: active.id,
        createdDate: now,
        updatedDate: now,
      ));
      expect(debtId, greaterThan(0));
      final debtTx = await db.insertTransaction(Transaction(
        type: 'income',
        amount: 10000,
        category: 'Hutang',
        description: 'Terima',
        date: now,
        wallet: cash.name,
        walletId: cash.id,
      ));
      await expectLater(
        db.updateTransactionDetails(
            transactionId: debtTx,
            category: 'Gaji',
            description: 'Ubah',
            date: now),
        throwsStateError,
      );
    });
  });
}
