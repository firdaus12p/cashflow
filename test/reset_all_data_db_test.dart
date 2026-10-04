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

  Future<int> rowCount(DatabaseHelper db, String table) async {
    final result = await (await db.database).rawQuery(
      'SELECT COUNT(*) AS c FROM $table',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> populateAllDomains(DatabaseHelper db) async {
    final now = DateTime.now();

    final walletId = await db.insertWallet(
      Wallet(name: 'Test Wallet', createdDate: now, updatedDate: now),
    );

    final bucketId = await db.insertFinancialBucket(
      FinancialBucket(
        name: 'Test Pos',
        allocationPercentage: 100,
        walletId: walletId,
        createdDate: now,
        updatedDate: now,
      ),
    );

    final txId = await db.insertTransaction(
      Transaction(
        type: 'income',
        amount: 1000,
        category: 'Gaji',
        description: 'Test',
        date: now,
        wallet: 'Test Wallet',
        affectsBalance: false,
      ),
    );

    await (await db.database).insert('transaction_bucket_allocations', {
      'transactionId': txId,
      'bucketId': bucketId,
      'normalizedPercentage': 100,
      'allocatedAmount': 1000,
      'role': 'target',
      'createdDate': now.millisecondsSinceEpoch,
    });

    await (await db.database).insert('bucket_transfers', {
      'fromBucketId': bucketId,
      'toBucketId': bucketId,
      'amount': 0,
      'note': 'test',
      'transferDate': now.millisecondsSinceEpoch,
      'createdDate': now.millisecondsSinceEpoch,
    });

    await db.insertSavingGoal(
      SavingGoal(name: 'Goal', targetAmount: 100, createdDate: now),
    );

    await db.insertWishlistItem(
      WishlistItem(name: 'Item', price: 50, createdDate: now),
    );

    await db.insertBadge(
      UserBadge(
        name: 'First',
        description: 'desc',
        emoji: '🏅',
        earnedDate: now,
        type: 'first',
      ),
    );

    final debtId = await db.insertDebt(
      Debt(
        type: 'debt',
        personName: 'Orang',
        principalAmount: 200,
        remainingAmount: 200,
        borrowedDate: now,
        recordingMode: 'note',
        status: 'active',
        createdDate: now,
        updatedDate: now,
      ),
    );

    await (await db.database).insert('debt_payments', {
      'debtId': debtId,
      'amount': 50,
      'paymentDate': now.millisecondsSinceEpoch,
      'recordingMode': 'note',
      'note': '',
      'createdDate': now.millisecondsSinceEpoch,
    });

    await db.setAppPreference('homeBalanceSourceType', 'total');
    await db.setAppPreference('bucketSystemEnabled', 'true');
  }

  group('resetAllData — domain cleared', () {
    test('setelah populasi semua domain lalu reset, tabel user data kosong',
        () async {
      final db = DatabaseHelper();
      await populateAllDomains(db);

      expect(await rowCount(db, 'transactions'), greaterThan(0));
      expect(await rowCount(db, 'saving_goals'), greaterThan(0));
      expect(await rowCount(db, 'wishlist'), greaterThan(0));
      expect(await rowCount(db, 'badges'), greaterThan(0));
      expect(await rowCount(db, 'debts'), greaterThan(0));
      expect(await rowCount(db, 'debt_payments'), greaterThan(0));
      expect(await rowCount(db, 'financial_buckets'), greaterThan(0));
      expect(
        await rowCount(db, 'transaction_bucket_allocations'),
        greaterThan(0),
      );
      expect(await rowCount(db, 'bucket_transfers'), greaterThan(0));
      expect(await rowCount(db, 'app_preferences'), greaterThan(0));

      await db.resetAllData();

      expect(await rowCount(db, 'transactions'), 0);
      expect(await rowCount(db, 'saving_goals'), 0);
      expect(await rowCount(db, 'wishlist'), 0);
      expect(await rowCount(db, 'badges'), 0);
      expect(await rowCount(db, 'debts'), 0);
      expect(await rowCount(db, 'debt_payments'), 0);
      expect(await rowCount(db, 'financial_buckets'), 0);
      expect(await rowCount(db, 'transaction_bucket_allocations'), 0);
      expect(await rowCount(db, 'bucket_transfers'), 0);
      expect(await rowCount(db, 'app_preferences'), 0);
    });

    test('setelah reset, empat dompet default tersedia kembali', () async {
      final db = DatabaseHelper();
      await populateAllDomains(db);

      await db.resetAllData();

      final wallets = await db.getActiveWallets();
      final names = wallets.map((w) => w.name).toSet();
      expect(names, containsAll(['Cash', 'E-Wallet', 'Bank', 'Tabungan']));
    });

    test('setelah reset, dompet default tidak terduplikasi', () async {
      final db = DatabaseHelper();
      await db.resetAllData();
      await db.resetAllData();

      final wallets = await db.getActiveWallets();
      final cashCount = wallets.where((w) => w.name == 'Cash').length;
      expect(cashCount, 1);
    });

    test('reset pada DB kosong tidak melempar exception', () async {
      final db = DatabaseHelper();
      expect(() async => db.resetAllData(), returnsNormally);
    });

    test('setelah reset, app_preferences benar-benar kosong', () async {
      final db = DatabaseHelper();
      await db.setAppPreference('bucketSystemEnabled', 'true');
      await db.setAppPreference('homeBalanceSourceType', 'wallet');

      await db.resetAllData();

      final prefs = await db.getAppPreferences(
        ['bucketSystemEnabled', 'homeBalanceSourceType'],
      );
      expect(prefs, isEmpty);
    });
  });
}
