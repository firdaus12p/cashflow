// DB-level regressions for the approved finance integrity fixes.
import 'package:cashflow/core/constants/app_constants.dart';
import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/debts/models/debt_models.dart';
import 'package:cashflow/features/transactions/models/transaction.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final helper = DatabaseHelper();
  final now = DateTime(2026, 9, 5);
  late Wallet cash;
  late Wallet bank;

  setUpAll(initializeSharedTestDatabase);
  setUp(() async {
    await resetSharedTestDatabase();
    final wallets = await helper.getActiveWallets();
    cash = wallets.firstWhere((wallet) => wallet.name == 'Cash');
    bank = wallets.firstWhere((wallet) => wallet.name == 'Bank');
  });
  tearDownAll(disposeSharedTestDatabase);

  Transaction transaction(String type, double amount, {int? walletId}) =>
      Transaction(
        type: type,
        amount: amount,
        category: 'Test',
        description: 'Original',
        date: now,
        wallet: cash.name,
        walletId: walletId,
      );

  Future<FinancialBucket> bucket({double balance = 0, int? walletId}) async {
    final id = await helper.insertFinancialBucket(FinancialBucket(
      name: 'Bucket',
      walletId: walletId ?? cash.id,
      allocationPercentage: 100,
      currentBalance: balance,
      createdDate: now,
      updatedDate: now,
    ));
    return (await helper.getFinancialBuckets()).firstWhere((b) => b.id == id);
  }

  FinancialBucket editBucket(FinancialBucket original,
          {int? walletId, String name = 'Edited'}) =>
      FinancialBucket(
        id: original.id,
        name: name,
        walletId: walletId ?? original.walletId,
        allocationPercentage: original.allocationPercentage,
        currentBalance: original.currentBalance,
        isArchived: original.isArchived,
        createdDate: original.createdDate,
        updatedDate: now,
      );

  Future<int> debt({int? bucketId}) => helper.insertDebt(Debt(
        type: 'debt',
        personName: 'Test',
        principalAmount: 100000,
        remainingAmount: 100000,
        borrowedDate: now,
        recordingMode: 'note',
        bucketId: bucketId,
        createdDate: now,
        updatedDate: now,
      ));

  // Capture each outcome so Future.wait verifies both concurrent attempts.
  Future<Object?> outcome(Future<dynamic> operation) async {
    try {
      await operation;
      return null;
    } catch (error) {
      return error;
    }
  }

  test('concurrent direct expenses cannot spend the same balance twice',
      () async {
    await helper
        .insertTransaction(transaction('income', 100000, walletId: cash.id));
    final results = await Future.wait(List.generate(
        2,
        (_) => outcome(
              helper.insertTransaction(
                  transaction('expense', 80000, walletId: cash.id)),
            )));
    expect(results.where((result) => result == null), hasLength(1));
    expect(results.whereType<InsufficientBalanceException>(), hasLength(1));
    final transactions = await helper.getTransactions();
    expect(transactions.where((tx) => tx.type == 'expense'), hasLength(1));
    await helper
        .insertTransaction(transaction('expense', 20000, walletId: cash.id));
    await expectLater(
      helper.insertTransaction(transaction('expense', 1, walletId: cash.id)),
      throwsA(isA<InsufficientBalanceException>()),
    );
  });

  for (final mode in ['note', 'balance']) {
    test('concurrent $mode payments re-read remaining debt inside transaction',
        () async {
      final source = await bucket();
      await helper.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Seed',
        description: 'Funding',
        date: now,
        walletName: cash.name,
        subsetBuckets: [source],
      );
      final debtId = await debt();
      final results = await Future.wait(List.generate(
          2,
          (_) => outcome(
                helper.recordDebtPayment(
                  debtId: debtId,
                  amount: 80000,
                  paymentDate: now,
                  recordingMode: mode,
                  affectedBucket: mode == 'balance' ? source : null,
                ),
              )));
      expect(results.where((result) => result == null), hasLength(1));
      expect(results.whereType<RangeError>(), hasLength(1));
      expect((await helper.getDebtById(debtId))!.remainingAmount, 20000);
      expect((await helper.getDebtById(debtId))!.status, 'active');
      expect(await helper.getDebtPaymentsByDebt(debtId), hasLength(1));
      expect((await helper.getFinancialBuckets()).single.currentBalance,
          mode == 'balance' ? 120000 : 200000);
      expect(
          (await helper.getTransactions()).length, mode == 'balance' ? 2 : 1);
    });
  }

  test('missing debt throws without recording payment or transaction',
      () async {
    await expectLater(
        helper.recordDebtPayment(
          debtId: 999,
          amount: 100,
          paymentDate: now,
          recordingMode: 'balance',
        ),
        throwsStateError);
    expect(await helper.getDebtPaymentsByDebt(999), isEmpty);
    expect(await helper.getTransactions(), isEmpty);
  });

  for (final withBucket in [false, true]) {
    test(
        'description-only expense edit is not double charged (bucket=$withBucket)',
        () async {
      final source = withBucket ? await bucket() : null;
      if (source != null) {
        await helper.saveIncomeWithAllocations(
          amount: 100000,
          category: 'Seed',
          description: 'Funding',
          date: now,
          walletName: cash.name,
          subsetBuckets: [source],
        );
      } else {
        await helper.insertTransaction(
            transaction('income', 100000, walletId: cash.id));
      }
      final id = source == null
          ? await helper.insertTransaction(
              transaction('expense', 80000, walletId: cash.id))
          : await helper.saveExpenseWithSource(
              amount: 80000,
              category: 'Test',
              description: 'Original',
              date: now,
              walletName: cash.name,
              sourceBucket: source,
            );
      Future<int> edit(double amount) => helper.updateTransaction(
            transactionId: id,
            type: 'expense',
            amount: amount,
            category: 'Test',
            description: 'Edited',
            date: now,
            walletName: cash.name,
            walletId: cash.id,
            sourceBucket: source,
            allowWithoutBucketAllocation: !withBucket,
          );
      expect(await edit(80000), 1);
      final edited =
          (await helper.getTransactions()).firstWhere((tx) => tx.id == id);
      expect(edited.description, 'Edited');
      expect(edited.amount, 80000);
      if (source != null) {
        expect(
            (await helper.getFinancialBuckets()).single.currentBalance, 20000);
        expect(
            (await helper.getTransactionBucketAllocations(id))
                .single
                .allocatedAmount,
            80000);
      }
      await expectLater(
          edit(100001), throwsA(isA<InsufficientBalanceException>()));
      expect(
          (await helper.getTransactions())
              .firstWhere((tx) => tx.id == id)
              .amount,
          80000);
      if (source != null) {
        expect(
            (await helper.getFinancialBuckets()).single.currentBalance, 20000);
        expect(
            (await helper.getTransactionBucketAllocations(id))
                .single
                .allocatedAmount,
            80000);
      }
      expect(await edit(100000), 1);
      await expectLater(
        helper.insertTransaction(transaction('expense', 1, walletId: cash.id)),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });
  }

  test('expense edit to another wallet uses the new bucket owner exactly once',
      () async {
    final source = await bucket();
    final target = await bucket(walletId: bank.id);
    for (final b in [source, target]) {
      await helper.saveIncomeWithAllocations(
        amount: 100000,
        category: 'Seed',
        description: 'Funding',
        date: now,
        walletName: cash.name,
        subsetBuckets: [b],
      );
    }
    final id = await helper.saveExpenseWithSource(
      amount: 80000,
      category: 'Test',
      description: 'Original',
      date: now,
      walletName: cash.name,
      sourceBucket: source,
    );
    await helper.updateTransaction(
      transactionId: id,
      type: 'expense',
      amount: 80000,
      category: 'Test',
      description: 'Edited',
      date: now,
      walletName: cash.name,
      walletId: cash.id,
      sourceBucket: target,
    );
    final edited =
        (await helper.getTransactions()).firstWhere((tx) => tx.id == id);
    expect(edited.walletId, bank.id);
    expect(edited.wallet, bank.name);
    final previews = await helper.previewBucketReconciliations();
    expect(previews[cash.id]!.delta, 0);
    expect(previews[bank.id]!.delta, 0);
  });

  for (final history in [
    'balance',
    'allocation',
    'transferFrom',
    'transferTo',
    'debt',
    'payment'
  ]) {
    test('bucket owner change rejects $history and permits same-owner metadata',
        () async {
      final source = await bucket(balance: history == 'balance' ? 10 : 0);
      final db = await helper.database;
      if (history == 'allocation') {
        final txId = await helper.insertTransaction(transaction('income', 100));
        await db.insert('transaction_bucket_allocations', {
          'transactionId': txId,
          'bucketId': source.id,
          'normalizedPercentage': 100,
          'allocatedAmount': 100,
          'role': 'target',
          'createdDate': 1,
        });
      } else if (history.startsWith('transfer')) {
        final other = await bucket();
        await db.insert('bucket_transfers', {
          'fromBucketId': history == 'transferFrom' ? source.id : other.id,
          'toBucketId': history == 'transferTo' ? source.id : other.id,
          'amount': 100,
          'transferDate': 1,
          'createdDate': 1,
        });
      } else if (history == 'debt') {
        await debt(bucketId: source.id);
      } else if (history == 'payment') {
        final debtId = await debt();
        await helper.recordDebtPayment(
          debtId: debtId,
          amount: 100,
          paymentDate: now,
          recordingMode: 'note',
          bucketId: source.id,
        );
      }
      final before = await db
          .query('financial_buckets', where: 'id = ?', whereArgs: [source.id]);
      await expectLater(
          helper.updateFinancialBucket(editBucket(source, walletId: bank.id)),
          throwsStateError);
      expect(
          await db.query('financial_buckets',
              where: 'id = ?', whereArgs: [source.id]),
          before);
      expect(await helper.updateFinancialBucket(editBucket(source)), 1);
      final updated = (await helper.getFinancialBuckets())
          .firstWhere((b) => b.id == source.id);
      expect(updated.name, 'Edited');
      expect(updated.walletId, cash.id);
      expect(updated.currentBalance, source.currentBalance);
    });
  }

  test('unused empty bucket may change to another active owner', () async {
    final source = await bucket();
    expect(
        await helper
            .updateFinancialBucket(editBucket(source, walletId: bank.id)),
        1);
    expect((await helper.getFinancialBuckets()).single.walletId, bank.id);
  });

  for (final action in ['archive', 'delete', 'update']) {
    test('$action wallet rejects even empty active buckets atomically',
        () async {
      await bucket();
      final db = await helper.database;
      final before = await db.query('wallets');
      final operation = action == 'archive'
          ? helper.archiveWallet(cash.id!)
          : action == 'delete'
              ? helper.deleteWallet(cash.id!)
              : helper.updateWallet(Wallet(
                  id: cash.id,
                  name: 'Changed',
                  isArchived: true,
                  createdDate: cash.createdDate,
                  updatedDate: now,
                ));
      await expectLater(operation, throwsStateError);
      expect(await db.query('wallets'), before);
    });
  }

  test('archived buckets retain their wallet instead of allowing hard deletion',
      () async {
    final source = await bucket();
    await bucket(walletId: bank.id);
    await helper.archiveFinancialBucket(source.id!);
    expect(await helper.getWalletReferenceCount(cash), 1);
    await helper.deleteWallet(cash.id!);
    expect(
        (await helper.getWallets())
            .firstWhere((w) => w.id == cash.id)
            .isArchived,
        isTrue);
    expect(
        (await helper.getFinancialBuckets())
            .firstWhere((b) => b.id == source.id)
            .walletId,
        cash.id);
  });

  test('transfer wallet snapshots count as historical references', () async {
    final db = await helper.database;
    await db.insert('bucket_transfers', {
      'fromBucketId': 10,
      'toBucketId': 11,
      'fromWalletIdSnapshot': cash.id,
      'toWalletIdSnapshot': bank.id,
      'amount': 100,
      'transferDate': 1,
      'createdDate': 1,
    });
    expect(await helper.getWalletReferenceCount(cash), 1);
    expect(await helper.getWalletReferenceCount(bank), 1);
    await helper.deleteWallet(cash.id!);
    expect(
        (await helper.getWallets())
            .firstWhere((w) => w.id == cash.id)
            .isArchived,
        isTrue);
  });

  test(
      'historical bucket metadata remains editable with unchanged archived owner',
      () async {
    final source = await bucket();
    await bucket(walletId: bank.id);
    await helper.archiveFinancialBucket(source.id!);
    await helper.archiveWallet(cash.id!);
    final archived = (await helper.getFinancialBuckets())
        .firstWhere((b) => b.id == source.id);
    expect(await helper.updateFinancialBucket(editBucket(archived)), 1);
    final updated = (await helper.getFinancialBuckets())
        .firstWhere((b) => b.id == source.id);
    expect(updated.walletId, cash.id);
    expect(updated.isArchived, isTrue);
    expect(updated.name, 'Edited');
  });

  test('archived owner cannot gain a new or reassigned bucket', () async {
    final source = await bucket();
    await helper.archiveWallet(bank.id!);
    await expectLater(bucket(walletId: bank.id), throwsStateError);
    await expectLater(
        helper.updateFinancialBucket(editBucket(source, walletId: bank.id)),
        throwsStateError);
  });

  test(
      'legacy unbound wallet income and expenses remain spendable after rename',
      () async {
    await helper.insertTransaction(transaction('income', 100000));
    await helper.insertTransaction(transaction('expense', 20000));
    final source = await bucket();
    expect(
        (await helper.previewBucketReconciliations())[cash.id]!.delta, 80000);
    await helper.applyBucketReconciliations();
    await helper.updateWallet(Wallet(
      id: cash.id,
      name: 'Renamed Cash',
      createdDate: cash.createdDate,
      updatedDate: now,
    ));
    await helper.saveExpenseWithSource(
      amount: 80000,
      category: 'Test',
      description: 'Spend legacy',
      date: now,
      walletName: 'Renamed Cash',
      walletId: cash.id,
      sourceBucket: source,
    );
    expect((await helper.getFinancialBuckets()).single.currentBalance, 0);
    expect((await helper.previewBucketReconciliations())[cash.id]!.delta, 0);
    await expectLater(
      helper.insertTransaction(transaction('expense', 1, walletId: cash.id)),
      throwsA(isA<InsufficientBalanceException>()),
    );
  });

  test('legacy allocated income is not counted both directly and by allocation',
      () async {
    final source = await bucket();
    final txId = await helper.saveIncomeWithAllocations(
      amount: 100000,
      category: 'Seed',
      description: 'Funding',
      date: now,
      walletName: cash.name,
      subsetBuckets: [source],
    );
    final db = await helper.database;
    await db.update('transactions', {'walletId': null},
        where: 'id = ?', whereArgs: [txId]);
    expect((await helper.previewBucketReconciliations())[cash.id]!.delta, 0);
    await helper
        .insertTransaction(transaction('expense', 100000, walletId: cash.id));
    await expectLater(
      helper.insertTransaction(transaction('expense', 1, walletId: cash.id)),
      throwsA(isA<InsufficientBalanceException>()),
    );
  });

  test('invalid payment and direct transaction amounts leave no records',
      () async {
    final debtId = await debt();
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
          helper.recordDebtPayment(
            debtId: debtId,
            amount: amount,
            paymentDate: now,
            recordingMode: 'note',
          ),
          throwsArgumentError);
      await expectLater(
          helper.insertTransaction(transaction('expense', amount)),
          throwsArgumentError);
    }
    expect(await helper.getDebtPaymentsByDebt(debtId), isEmpty);
    expect((await helper.getDebtById(debtId))!.remainingAmount, 100000);
    expect(await helper.getTransactions(), isEmpty);
  });

  for (final operation in [
    'direct income',
    'direct expense',
    'insert debt',
    'update debt',
    'create debt wallet',
    'create debt bucket',
    'payment note',
    'payment wallet',
    'payment bucket',
    'transfer',
    'allocated income',
    'bucket expense',
    'note expense',
  ]) {
    test('$operation rolls back on metadata failure and retry commits once',
        () async {
      final db = await helper.database;
      final source = await bucket();
      final target = await bucket(walletId: bank.id);
      await helper.saveIncomeWithAllocations(
        amount: 200000,
        category: 'Seed',
        description: 'Funding',
        date: now,
        walletName: cash.name,
        subsetBuckets: [source],
      );
      final debtId = await debt();
      final debtRecord = Debt(
        id: operation == 'update debt' ? debtId : null,
        type: 'debt',
        personName: 'Changed',
        principalAmount: 100000,
        remainingAmount: 100000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: cash.id,
        createdDate: now,
        updatedDate: now,
      );
      Future<void> runOperation() async {
        switch (operation) {
          case 'direct income':
          case 'direct expense':
            await helper.insertTransaction(transaction(
              operation == 'direct income' ? 'income' : 'expense',
              100000,
              walletId: cash.id,
            ));
          case 'insert debt':
            await helper.insertDebt(debtRecord);
          case 'update debt':
            await helper.updateDebt(debtRecord);
          case 'create debt wallet':
          case 'create debt bucket':
            await helper.createDebtWithBalanceEffect(
              debt: debtRecord,
              walletName: cash.name,
              bucketSystemEnabled: operation == 'create debt bucket',
              affectedBucket: operation == 'create debt bucket' ? source : null,
            );
          case 'payment note':
          case 'payment wallet':
          case 'payment bucket':
            await helper.recordDebtPayment(
              debtId: debtId,
              amount: 100000,
              paymentDate: now,
              recordingMode: operation == 'payment note' ? 'note' : 'balance',
              walletId: cash.id,
              walletName: cash.name,
              affectedBucket: operation == 'payment bucket' ? source : null,
            );
          case 'transfer':
            await helper.executeBucketTransfer(
              fromBucketId: source.id!,
              toBucketId: target.id!,
              amount: 100000,
              transferDate: now,
            );
          case 'allocated income':
            await helper.saveIncomeWithAllocations(
              amount: 100000,
              category: 'Test',
              description: 'New',
              date: now,
              walletName: cash.name,
              subsetBuckets: [source],
            );
          case 'bucket expense':
            await helper.saveExpenseWithSource(
              amount: 100000,
              category: 'Test',
              description: 'New',
              date: now,
              walletName: cash.name,
              sourceBucket: source,
            );
          case 'note expense':
            await helper.saveExpenseNoteOnly(
              amount: 100000,
              category: 'Test',
              description: 'New',
              date: now,
              walletName: cash.name,
            );
        }
      }

      // Preserve an existing metadata value to exercise the REPLACE path too.
      await helper.markFinancialActivity(now);
      const tables = [
        'transactions',
        'debts',
        'debt_payments',
        'financial_buckets',
        'transaction_bucket_allocations',
        'bucket_transfers',
        'wallets',
        'app_preferences',
        'sqlite_sequence',
      ];
      Future<Map<String, Object>> snapshot() async => {
            for (final table in tables)
              table: await db.query(table, orderBy: 'rowid'),
          };
      final before = await snapshot();
      await db.execute('''
        CREATE TRIGGER reject_financial_metadata BEFORE INSERT ON app_preferences
        WHEN NEW.key = '$reminderLastFinancialActivityAtPreferenceKey'
        BEGIN
          SELECT RAISE(ABORT, 'forced financial metadata failure');
        END
      ''');
      addTearDown(() async {
        await db.execute('DROP TRIGGER IF EXISTS reject_financial_metadata');
      });
      await expectLater(
        runOperation(),
        throwsA(predicate<Object>((error) =>
            error.toString().contains('forced financial metadata failure'))),
      );
      expect(await snapshot(), before,
          reason: 'Metadata failure must roll back every financial write');

      await db.execute('DROP TRIGGER reject_financial_metadata');
      await runOperation();
      final expectedTransactions = switch (operation) {
        'insert debt' || 'update debt' || 'payment note' => 1,
        'transfer' => 3,
        _ => 2,
      };
      expect(await helper.getTransactions(), hasLength(expectedTransactions));
      expect(
          await helper.getDebts(),
          hasLength(
            operation == 'insert debt' || operation.startsWith('create debt')
                ? 2
                : 1,
          ));
      expect(await helper.getDebtPaymentsByDebt(debtId),
          hasLength(operation.startsWith('payment') ? 1 : 0));
      if (operation.startsWith('payment')) {
        expect((await helper.getDebtById(debtId))!.remainingAmount, 0);
        expect((await helper.getDebtById(debtId))!.status, 'settled');
      }
      if (operation == 'update debt') {
        expect((await helper.getDebtById(debtId))!.personName, 'Changed');
      }
      expect(await helper.getBucketTransfers(),
          hasLength(operation == 'transfer' ? 1 : 0));
      final preferences = await helper.getReminderPreferences();
      expect(preferences.lastFinancialActivityAt, isNotNull);
      expect(preferences.lastFinancialActivityAt, isNot(now));
    });
  }
}
