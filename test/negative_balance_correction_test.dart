// Corrections may drive a balance below zero after confirmation; spending may not.
import 'package:cashflow/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final db = DatabaseHelper();
  final now = DateTime(2026, 9, 1);
  late Wallet cash;

  setUpAll(initializeSharedTestDatabase);
  setUp(() async {
    await resetSharedTestDatabase();
    cash = (await db.getActiveWallets()).firstWhere((w) => w.name == 'Cash');
  });
  tearDownAll(disposeSharedTestDatabase);

  Future<int> add(String type, double amount, {String desc = 'x'}) =>
      db.insertTransaction(Transaction(
        type: type,
        amount: amount,
        category: type == 'income' ? 'Gaji' : 'Makanan',
        description: desc,
        date: now,
        wallet: cash.name,
        walletId: cash.id,
      ));

  Future<double> cashBalance() async => calculateBalanceForWallet(
        await db.getTransactions(),
        selectedWallet: cash.name,
      );

  Future<int> editIncome(int id, double amount, {bool confirm = false}) =>
      db.updateTransaction(
        transactionId: id,
        type: 'income',
        amount: amount,
        category: 'Gaji',
        description: 'x',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        allowWithoutBucketAllocation: true,
        allowNegativeBalance: confirm,
      );

  final hardRejection = throwsA(allOf(
    isA<InsufficientBalanceException>(),
    isNot(isA<NegativeBalanceConfirmationRequired>()),
  ));

  group('koreksi dompet tanpa pos', () {
    late int salaryId;
    late int spendId;
    setUp(() async {
      salaryId = await add('income', 1000000, desc: 'Gaji typo');
      spendId = await add('expense', 800000, desc: 'Belanja');
    });

    test('hapus pemasukan yang membuat saldo minus: minta konfirmasi', () async {
      await expectLater(
        db.deleteTransaction(salaryId),
        throwsA(isA<NegativeBalanceConfirmationRequired>().having(
            (e) => e.impacts.map((i) => (i.name, i.isBucket, i.after)).toList(),
            'dampak',
            [('Cash', false, -800000.0)])),
      );
      expect(await cashBalance(), 200000);
      expect((await db.getTransactions()).any((t) => t.id == salaryId), isTrue);
    });

    test('hapus setelah konfirmasi: saldo menjadi minus', () async {
      await db.deleteTransaction(salaryId, allowNegativeBalance: true);
      expect(await cashBalance(), -800000);
    });

    test('kurangi nominal pemasukan: minta konfirmasi, lalu bisa dikoreksi',
        () async {
      await expectLater(editIncome(salaryId, 100000),
          throwsA(isA<NegativeBalanceConfirmationRequired>()));
      expect(await cashBalance(), 200000);
      await editIncome(salaryId, 100000, confirm: true);
      expect(await cashBalance(), -700000);
    });

    test('koreksi yang tetap tidak minus tidak perlu konfirmasi', () async {
      await editIncome(salaryId, 900000);
      expect(await cashBalance(), 100000);
    });

    test('pemasukan baru boleh masuk ke dompet yang sudah minus', () async {
      await db.deleteTransaction(salaryId, allowNegativeBalance: true);
      await add('income', 500000);
      expect(await cashBalance(), -300000);
    });

    test('pengeluaran baru ditolak keras saat dompet minus', () async {
      await db.deleteTransaction(salaryId, allowNegativeBalance: true);
      await expectLater(add('expense', 1), hardRejection);
      expect(await cashBalance(), -800000);
    });

    test('mengedit keterangan pengeluaran lama saat dompet minus tetap boleh',
        () async {
      await db.deleteTransaction(salaryId, allowNegativeBalance: true);
      await db.updateTransaction(
        transactionId: spendId,
        type: 'expense',
        amount: 800000,
        category: 'Makanan',
        description: 'Belanja bulanan',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        allowWithoutBucketAllocation: true,
      );
      expect(
          (await db.getTransactions())
              .firstWhere((t) => t.id == spendId)
              .description,
          'Belanja bulanan');
    });

    test('menaikkan nominal pengeluaran melebihi saldo tetap ditolak keras',
        () async {
      await expectLater(
        db.updateTransaction(
          transactionId: spendId,
          type: 'expense',
          amount: 1100000,
          category: 'Makanan',
          description: 'x',
          date: now,
          walletName: cash.name,
          walletId: cash.id,
          allowWithoutBucketAllocation: true,
        ),
        hardRejection,
      );
    });
  });

  group('koreksi dengan pos', () {
    late FinancialBucket a;
    late FinancialBucket b;
    late int incomeId;

    Future<FinancialBucket> reload(FinancialBucket x) async =>
        (await db.getFinancialBuckets()).firstWhere((y) => y.id == x.id);

    Future<FinancialBucket> pos(String name) async {
      final id = await db.insertFinancialBucket(FinancialBucket(
        name: name,
        walletId: cash.id,
        allocationPercentage: 50,
        createdDate: now,
        updatedDate: now,
      ));
      return (await db.getFinancialBuckets()).firstWhere((x) => x.id == id);
    }

    setUp(() async {
      a = await pos('Jajan');
      b = await pos('Tabungan');
      await db.setBucketSystemEnabled(true);
      incomeId = await db.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Gaji',
        description: 'Gaji',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        subsetBuckets: [a, b],
      );
      await db.saveExpenseWithSource(
        amount: 60000,
        category: 'Makanan',
        description: 'Bakso',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        sourceBucket: await reload(a),
      );
    });

    test('hapus pemasukan: pos dan dompet yang jadi minus disebut', () async {
      await expectLater(
        db.deleteTransaction(incomeId),
        throwsA(isA<NegativeBalanceConfirmationRequired>().having(
            (e) => e.impacts
                .map((i) => '${i.isBucket ? 'pos' : 'dompet'}:${i.name}')
                .toSet(),
            'nama terdampak',
            {'pos:Jajan', 'dompet:Cash'})),
      );
      expect((await reload(a)).currentBalance, 40000);
    });

    test('setelah konfirmasi pos minus; pemasukan baru tetap bisa masuk',
        () async {
      await db.deleteTransaction(incomeId, allowNegativeBalance: true);
      expect((await reload(a)).currentBalance, -60000);
      await db.saveIncomeWithAllocations(
        amount: 100000,
        category: 'Bonus',
        description: 'Bonus',
        date: now,
        walletName: cash.name,
        walletId: cash.id,
        subsetBuckets: [await reload(a), await reload(b)],
      );
      expect((await reload(a)).currentBalance, -10000);
    });

    test('pos minus tidak bisa jadi sumber transfer atau pengeluaran',
        () async {
      await db.deleteTransaction(incomeId, allowNegativeBalance: true);
      await expectLater(
        db.executeBucketTransfer(
            fromBucketId: a.id!,
            toBucketId: b.id!,
            amount: 1,
            transferDate: now),
        hardRejection,
      );
      await expectLater(
        db.saveExpenseWithSource(
          amount: 1,
          category: 'Makanan',
          description: 'x',
          date: now,
          walletName: cash.name,
          walletId: cash.id,
          sourceBucket: await reload(a),
        ),
        hardRejection,
      );
    });

    test('pos minus tetap tidak bisa dihapus', () async {
      await db.deleteTransaction(incomeId, allowNegativeBalance: true);
      await expectLater(
          db.removeFinancialBucketFromActive(a.id!), throwsStateError);
    });
  });
}
