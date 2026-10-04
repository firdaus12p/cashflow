import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/main.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final db = DatabaseHelper();
  final now = DateTime(2026, 9, 22);
  late Wallet wallet;
  setUpAll(initializeSharedTestDatabase);
  setUp(() async {
    await resetSharedTestDatabase();
    wallet = (await db.getActiveWallets()).first;
  });
  tearDownAll(disposeSharedTestDatabase);

  Future<int> tx(String type, double amount) =>
      db.insertTransaction(Transaction(
          type: type,
          amount: amount,
          category: 'Lainnya',
          description: 'original',
          date: now,
          wallet: wallet.name,
          walletId: wallet.id));
  Future<double> total() async =>
      (await db.getTransactions()).where((t) => t.affectsBalance).fold<double>(
          0, (v, t) => v + (t.type == 'income' ? t.amount : -t.amount));
  Future<FinancialBucket> bucket(String name,
      {double pct = 100, int? owner}) async {
    final id = await db.insertFinancialBucket(FinancialBucket(
        name: name,
        walletId: owner ?? wallet.id,
        allocationPercentage: pct,
        createdDate: now,
        updatedDate: now));
    return (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
  }

  Future<int> fund(FinancialBucket b, double amount) =>
      db.saveIncomeWithAllocations(
          amount: amount,
          category: 'Gaji',
          description: 'original',
          date: now,
          walletName: wallet.name,
          walletId: wallet.id,
          subsetBuckets: [b]);
  Future<int> spend(FinancialBucket b, double amount) =>
      db.saveExpenseWithSource(
          amount: amount,
          category: 'Belanja',
          description: 'expense',
          date: now,
          walletName: wallet.name,
          walletId: wallet.id,
          sourceBucket: b);
  Future<int> edit(int id, double amount,
          {String type = 'income',
          List<FinancialBucket>? buckets,
          FinancialBucket? source,
          int? owner}) =>
      db.updateTransaction(
          transactionId: id,
          type: type,
          amount: amount,
          category: 'Lainnya',
          description: 'edited',
          date: now,
          walletName: wallet.name,
          walletId: owner ?? wallet.id,
          subsetBuckets: buckets,
          sourceBucket: source,
          allowWithoutBucketAllocation: buckets == null && source == null);
  FinancialBucket config(FinancialBucket b,
          {double? pct, double? balance, bool? archived, int? owner}) =>
      FinancialBucket(
          id: b.id,
          name: 'renamed',
          walletId: owner ?? b.walletId,
          allocationPercentage: pct ?? b.allocationPercentage,
          currentBalance: balance ?? b.currentBalance,
          isArchived: archived ?? b.isArchived,
          createdDate: b.createdDate,
          updatedDate: now);
  Debt debt(
          {int? id,
          double amount = 100,
          double? remaining,
          String mode = 'note',
          String type = 'debt'}) =>
      Debt(
          id: id,
          type: type,
          personName: 'person',
          principalAmount: amount,
          remainingAmount: remaining ?? amount,
          borrowedDate: now,
          recordingMode: mode,
          walletId: wallet.id,
          createdDate: now,
          updatedDate: now);
  Future<Object?> outcome(Future<dynamic> f) async {
    try {
      await f;
      return null;
    } catch (e) {
      return e;
    }
  }

  test('spent wallet-only income cannot be deleted, reduced or moved',
      () async {
    final id = await tx('income', 100);
    await tx('expense', 80);
    await expectLater(
        db.deleteTransaction(id), throwsA(isA<InsufficientBalanceException>()));
    await expectLater(
        edit(id, 50), throwsA(isA<InsufficientBalanceException>()));
    final other = (await db.getActiveWallets()).last;
    await expectLater(edit(id, 100, owner: other.id),
        throwsA(isA<InsufficientBalanceException>()));
    expect(await total(), 20);
    expect(
        (await db.getTransactions()).firstWhere((t) => t.id == id).amount, 100);
  });

  test(
      'income metadata and increase work after spending; unsafe reduction rolls back',
      () async {
    final b = await bucket('fund');
    final id = await fund(b, 100);
    await spend(b, 80);
    await edit(id, 100, buckets: [b]);
    expect((await db.getFinancialBuckets()).single.currentBalance, 20);
    await edit(id, 120, buckets: [b]);
    expect((await db.getFinancialBuckets()).single.currentBalance, 40);
    await expectLater(edit(id, 50, buckets: [b]),
        throwsA(isA<InsufficientBalanceException>()));
    expect((await db.getFinancialBuckets()).single.currentBalance, 40);
    expect(
        (await db.getTransactionBucketAllocations(id)).single.allocatedAmount,
        120);
  });

  test('disabled bucket system cannot hide spent wallet funds during delete',
      () async {
    final b = await bucket('fund');
    final id = await fund(b, 100);
    await db.setBucketSystemEnabled(false);
    await tx('expense', 80);
    await expectLater(
        db.deleteTransaction(id), throwsA(isA<InsufficientBalanceException>()));
    expect(await total(), 20);
    expect((await db.getFinancialBuckets()).single.currentBalance, 100);
  });

  test('internal transfer legs reject edit and delete', () async {
    final other = (await db.getActiveWallets()).last;
    final a = await bucket('source', pct: 50);
    final b = await bucket('destination', pct: 50, owner: other.id);
    await fund(a, 100);
    await db.executeBucketTransfer(
        fromBucketId: a.id!, toBucketId: b.id!, amount: 40, transferDate: now);
    for (final t in (await db.getTransactions())
        .where((t) => t.category == internalTransferCategory)) {
      await expectLater(db.deleteTransaction(t.id!), throwsStateError);
      await expectLater(edit(t.id!, 20, type: t.type), throwsStateError);
    }
    expect(await total(), 100);
    expect((await db.getFinancialBuckets()).map((b) => b.currentBalance),
        [60, 40]);
  });

  test('wishlist consumes stored price once under concurrent requests',
      () async {
    final b = await bucket('fund');
    await fund(b, 300);
    final id = await db.insertWishlistItem(
        WishlistItem(name: 'stored', price: 100, createdDate: now));
    final stale =
        WishlistItem(id: id, name: 'stale', price: 1, createdDate: now);
    Future<void> buy() => db.purchaseWishlistItem(stale,
        walletName: wallet.name, sourceBucket: b);
    final outcomes = await Future.wait([outcome(buy()), outcome(buy())]);
    expect(outcomes.where((v) => v == null).length, 1);
    expect(outcomes.whereType<StateError>().length, 1);
    final expenses =
        (await db.getTransactions()).where((t) => t.type == 'expense');
    expect(expenses.single.amount, 100);
    expect(expenses.single.description, 'stored');
    expect((await db.getFinancialBuckets()).single.currentBalance, 200);
  });

  test('archived bucket cannot be spent, credited, transferred or refunded',
      () async {
    final a = await bucket('source', pct: 50);
    final b = await bucket('destination', pct: 50);
    await fund(a, 100);
    final expense = await spend(a, 100);
    await db.removeFinancialBucketFromActive(a.id!);
    await db.updateFinancialBucket(config(b, pct: 100));
    await expectLater(db.deleteTransaction(expense), throwsStateError);
    await expectLater(spend(a, 1), throwsStateError);
    await expectLater(fund(a, 1), throwsStateError);
    await expectLater(
        db.executeBucketTransfer(
            fromBucketId: b.id!,
            toBucketId: a.id!,
            amount: 1,
            transferDate: now),
        throwsStateError);
    expect(
        (await db.getFinancialBuckets())
            .firstWhere((b) => b.id == a.id)
            .currentBalance,
        0);
  });

  test('bucket config never overwrites balance or bypasses archive checks',
      () async {
    final b = await bucket('fund');
    await fund(b, 100);
    await db.updateFinancialBucket(config(b, balance: 999));
    expect((await db.getFinancialBuckets()).single.currentBalance, 100);
    await expectLater(
        db.updateFinancialBucket(config(b, archived: true)), throwsStateError);
    await expectLater(bucket('over', pct: 1), throwsStateError);
    await expectLater(db.updateFinancialBucket(config(b, pct: double.nan)),
        throwsArgumentError);
  });

  test('stale bucket owner and percentages are reloaded for new writes',
      () async {
    final other = (await db.getActiveWallets()).last;
    final b = await bucket('fund');
    await db.updateFinancialBucket(config(b, owner: other.id));
    final id = await fund(b, 100);
    final t = (await db.getTransactions()).single;
    expect(t.walletId, other.id);
    expect(
        (await db.getTransactionBucketAllocations(id)).single.allocatedAmount,
        100);
    await expectLater(
        db.saveIncomeWithAllocations(
            amount: 10,
            category: 'Gaji',
            description: 'duplicate',
            date: now,
            walletName: wallet.name,
            subsetBuckets: [b, b]),
        throwsArgumentError);
  });

  test('stale debt edit preserves latest paid totals and settled state',
      () async {
    final id = await db.insertDebt(debt());
    final stale = (await db.getDebtById(id))!;
    await db.recordDebtPayment(
        debtId: id, amount: 100, paymentDate: now, recordingMode: 'note');
    await db.updateDebt(stale);
    expect((await db.getDebtById(id))!.remainingAmount, 0);
    expect((await db.getDebtById(id))!.status, 'settled');
    await expectLater(
        db.updateDebt(debt(id: id, amount: 50)), throwsRangeError);
    await db.updateDebt(debt(id: id, amount: 150));
    expect((await db.getDebtById(id))!.remainingAmount, 50);
    expect((await db.getDebtPaymentsByDebt(id)).single.amount, 100);
  });

  test(
      'balance debt rejects financial changes but keeps newer payments on edit',
      () async {
    final id = await db.createDebtWithBalanceEffect(
        debt: debt(mode: 'balance'),
        walletName: wallet.name,
        bucketSystemEnabled: false);
    await expectLater(db.updateDebt(debt(id: id, amount: 200, mode: 'balance')),
        throwsStateError);
    await db.recordDebtPayment(
        debtId: id, amount: 40, paymentDate: now, recordingMode: 'note');
    await db.updateDebt(debt(id: id, mode: 'balance'));
    expect((await db.getDebtById(id))!.remainingAmount, 60);
    expect(await total(), 100);
  });

  test('all exposed monetary create APIs reject unsupported amounts', () async {
    for (final amount in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      9007199254740992.0
    ]) {
      await expectLater(tx('income', amount), throwsArgumentError);
      await expectLater(
          db.insertWishlistItem(
              WishlistItem(name: 'bad', price: amount, createdDate: now)),
          throwsArgumentError);
      await expectLater(
          db.insertDebt(debt(amount: amount)), throwsArgumentError);
      await expectLater(
          db.createDebtWithBalanceEffect(
              debt: debt(amount: amount, mode: 'balance'),
              walletName: wallet.name,
              bucketSystemEnabled: false),
          throwsArgumentError);
      await expectLater(
          db.insertSavingGoal(
              SavingGoal(name: 'bad', targetAmount: amount, createdDate: now)),
          throwsArgumentError);
    }
    expect(await db.getTransactions(), isEmpty);
    expect(await db.getDebts(), isEmpty);
  });

  test('wishlist failure rolls back debit and original item', () async {
    final b = await bucket('fund');
    await fund(b, 100);
    final id = await db.insertWishlistItem(
        WishlistItem(name: 'item', price: 80, createdDate: now));
    final raw = await db.database;
    await raw.execute(
        "CREATE TEMP TRIGGER fail_wishlist BEFORE DELETE ON wishlist BEGIN SELECT RAISE(ABORT, 'test'); END");
    try {
      final i = (await db.getWishlistItems()).single;
      expect(
          await outcome(db.purchaseWishlistItem(i,
              walletName: wallet.name, sourceBucket: b)),
          isNotNull);
      expect((await db.getWishlistItems()).single.id, id);
      expect((await db.getFinancialBuckets()).single.currentBalance, 100);
      expect((await db.getTransactions()).length, 1);
    } finally {
      await raw.execute('DROP TRIGGER fail_wishlist');
    }
  });

  test('deleted wishlist and corrupted legacy price cannot create an expense',
      () async {
    await tx('income', 100);
    final id = await db.insertWishlistItem(
        WishlistItem(name: 'item', price: 50, createdDate: now));
    final item = (await db.getWishlistItems()).single;
    final raw = await db.database;
    await raw.update('wishlist', {'price': -50},
        where: 'id = ?', whereArgs: [id]);
    await expectLater(db.purchaseWishlistItem(item, walletName: wallet.name),
        throwsArgumentError);
    await db.deleteWishlistItem(id);
    await expectLater(db.purchaseWishlistItem(item, walletName: wallet.name),
        throwsStateError);
    expect(await total(), 100);
  });

  test(
      'concurrent bucket config cannot exceed 100 and draft cannot receive funds',
      () async {
    final a = await bucket('a', pct: 50);
    await expectLater(fund(a, 100), throwsStateError);
    final results = await Future.wait(
        [outcome(bucket('b', pct: 50)), outcome(bucket('c', pct: 50))]);
    expect(results.where((r) => r == null).length, 1);
    expect(results.whereType<StateError>().length, 1);
    expect(
        (await db.getFinancialBuckets())
            .fold<double>(0, (s, b) => s + b.allocationPercentage),
        100);
    await fund(a, 100);
    expect(await total(), 100);
  });

  test(
      'income allocation uses current stored percentages rather than stale payload',
      () async {
    final a = await bucket('a', pct: 50);
    final b = await bucket('b', pct: 50);
    await db.updateFinancialBucket(config(a, pct: 25));
    await db.updateFinancialBucket(config(b, pct: 75));
    final id = await db.saveIncomeWithAllocations(
        amount: 100,
        category: 'Gaji',
        description: 'current percentages',
        date: now,
        walletName: wallet.name,
        subsetBuckets: [a, b]);
    final amounts = {
      for (final a in await db.getTransactionBucketAllocations(id))
        a.bucketId: a.allocatedAmount
    };
    expect(amounts, {a.id: 25, b.id: 75});
  });

  test('note to balance conversion cannot leave spent income negative',
      () async {
    final id = await tx('income', 100);
    await tx('expense', 80);
    await expectLater(
        db.updateTransaction(
            transactionId: id,
            type: 'income',
            amount: 100,
            category: 'Lainnya',
            description: 'note',
            date: now,
            walletName: wallet.name,
            walletId: wallet.id,
            affectsBalance: false),
        throwsA(isA<InsufficientBalanceException>()));
    expect(await total(), 20);
  });

  test('payment alias preserves atomic remaining and returns its inserted ID',
      () async {
    final id = await db.insertDebt(debt());
    final paymentId = await db.insertDebtPayment(DebtPayment(
        debtId: id,
        amount: 40,
        paymentDate: now,
        recordingMode: 'note',
        createdDate: now));
    expect((await db.getDebtPaymentsByDebt(id)).single.id, paymentId);
    expect((await db.getDebtById(id))!.remainingAmount, 60);
    await expectLater(
        db.recordDebtPayment(
            debtId: id, amount: 10, paymentDate: now, recordingMode: 'invalid'),
        throwsArgumentError);
  });

  test('concurrent expense and payment checks remain inside SQLite transaction',
      () async {
    await tx('income', 100);
    final expenses = await Future.wait(
        [outcome(tx('expense', 80)), outcome(tx('expense', 80))]);
    expect(expenses.where((e) => e == null).length, 1);
    expect(await total(), 20);
    final id = await db.insertDebt(debt());
    Future<int> pay() => db.recordDebtPayment(
        debtId: id, amount: 80, paymentDate: now, recordingMode: 'note');
    final payments = await Future.wait([outcome(pay()), outcome(pay())]);
    expect(payments.where((e) => e == null).length, 1);
    expect((await db.getDebtById(id))!.remainingAmount, 20);
  });

  test('goal updates and aggregate balance overflow are rejected', () async {
    final id = await db.insertSavingGoal(
        SavingGoal(name: 'goal', targetAmount: 100, createdDate: now));
    await expectLater(
        db.updateSavingGoal(SavingGoal(
            id: id,
            name: 'goal',
            targetAmount: 100,
            currentAmount: double.infinity,
            createdDate: now)),
        throwsArgumentError);
    await tx('income', 9007199254740991);
    await expectLater(tx('income', 1), throwsStateError);
    expect((await db.getTransactions()).length, 1);
  });

  test('archived bucket cannot receive debt balance or receivable payment',
      () async {
    final a = await bucket('a', pct: 50);
    final b = await bucket('b', pct: 50);
    await db.removeFinancialBucketFromActive(a.id!);
    await db.updateFinancialBucket(config(b, pct: 100));
    await expectLater(
        db.createDebtWithBalanceEffect(
            debt: debt(mode: 'balance'),
            walletName: wallet.name,
            bucketSystemEnabled: true,
            affectedBucket: a),
        throwsStateError);
    final id = await db.insertDebt(debt(type: 'receivable'));
    await expectLater(
        db.recordDebtPayment(
            debtId: id,
            amount: 50,
            paymentDate: now,
            recordingMode: 'balance',
            affectedBucket: a),
        throwsStateError);
    expect((await db.getDebtById(id))!.remainingAmount, 100);
    expect(await db.getDebtPaymentsByDebt(id), isEmpty);
  });
}
