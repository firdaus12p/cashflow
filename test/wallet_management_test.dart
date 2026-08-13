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
  // CRUD Dompet (database level) — pakai test() bukan testWidgets()
  // ---------------------------------------------------------------------------

  group('CRUD dompet — database level', () {
    test('insertWallet lalu getActiveWallets mengembalikan dompet baru',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      await db.insertWallet(Wallet(
        name: 'Dompet Test',
        createdDate: now,
        updatedDate: now,
      ));

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.name == 'Dompet Test'), isTrue);
    });

    test('deleteWallet membuat dompet tanpa referensi hilang dari daftar aktif',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final id = await db.insertWallet(Wallet(
        name: 'Dompet Arsip',
        createdDate: now,
        updatedDate: now,
      ));

      await db.deleteWallet(id);

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.name == 'Dompet Arsip'), isFalse);

      final all = await db.getWallets();
      expect(all.any((w) => w.name == 'Dompet Arsip'), isFalse);
    });

    test('getActiveWallets tidak termasuk wallet yang isArchived=1', () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      await db.insertWallet(
          Wallet(name: 'W Aktif', createdDate: now, updatedDate: now));
      final id2 = await db.insertWallet(
          Wallet(name: 'W Arsip', createdDate: now, updatedDate: now));
      await db.deleteWallet(id2);

      final actives = await db.getActiveWallets();
      final names = actives.map((w) => w.name).toList();
      expect(names, contains('W Aktif'));
      expect(names, isNot(contains('W Arsip')));
    });

    test(
        'walletNameSnapshot tetap terbaca setelah dompet dihapus dari daftar aktif',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Historis',
        createdDate: now,
        updatedDate: now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 50000.0,
        'category': 'Makanan',
        'description': 'Test',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Dompet Historis',
        'walletId': walletId,
        'walletNameSnapshot': 'Dompet Historis',
        'affectsBalance': 1,
      });

      await db.deleteWallet(walletId);

      final rows = await rawDb.query(
        'transactions',
        where: 'walletId = ?',
        whereArgs: [walletId],
      );
      expect(rows.first['walletNameSnapshot'], 'Dompet Historis');
    });

    test('fresh install tidak lagi memaksa dompet bawaan aktif', () async {
      final db = DatabaseHelper();
      await db.database;

      final actives = await db.getActiveWallets();
      expect(actives, isEmpty);
    });

    test('updateWallet menyimpan perubahan nama', () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final id = await db.insertWallet(
          Wallet(name: 'Nama Lama', createdDate: now, updatedDate: now));

      final wallets = await db.getWallets();
      final wallet = wallets.firstWhere((w) => w.id == id);
      await db.updateWallet(Wallet(
        id: wallet.id,
        name: 'Nama Baru',
        createdDate: wallet.createdDate,
        updatedDate: DateTime.now(),
      ));

      final updated = await db.getWallets();
      expect(updated.any((w) => w.name == 'Nama Baru'), isTrue);
      expect(updated.any((w) => w.name == 'Nama Lama'), isFalse);
    });

    test(
        'updateWallet membackfill walletId untuk transaksi legacy sebelum rename',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(
          Wallet(name: 'Nama Lama', createdDate: now, updatedDate: now));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 45000.0,
        'category': 'Makanan',
        'description': 'Legacy transaksi',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Nama Lama',
        'walletNameSnapshot': '',
        'affectsBalance': 1,
      });

      await db.updateWallet(Wallet(
        id: walletId,
        name: 'Nama Baru',
        createdDate: now,
        updatedDate: now,
      ));

      final rows = await rawDb.query('transactions');
      expect(rows.single['walletId'], walletId);
      expect(rows.single['walletNameSnapshot'], 'Nama Lama');
      expect(rows.single['wallet'], 'Nama Lama');
    });

    test('getActiveWallets setelah delete tidak mengandung wallet tersebut',
        () async {
      final db = DatabaseHelper();
      await db.database;
      final now = DateTime.now();
      final walletId = await db.insertWallet(
        Wallet(name: 'Wallet Delete', createdDate: now, updatedDate: now),
      );
      await db.deleteWallet(walletId);

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.id == walletId), isFalse);
    });

    test('getWalletReferenceCount menghitung transaksi legacy tanpa walletId',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Legacy Wallet',
        createdDate: now,
        updatedDate: now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 25000.0,
        'category': 'Makanan',
        'description': 'Legacy transaksi',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Legacy Wallet',
        'walletNameSnapshot': 'Legacy Wallet',
        'affectsBalance': 1,
      });

      final wallet =
          (await db.getWallets()).firstWhere((w) => w.id == walletId);
      final referenceCount = await db.getWalletReferenceCount(wallet);
      expect(referenceCount, 1);
    });

    test('deleteWallet mengarsipkan dompet bila masih direferensikan debt',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Debt',
        createdDate: now,
        updatedDate: now,
      ));

      await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 150000,
        remainingAmount: 150000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: walletId,
        createdDate: now,
        updatedDate: now,
      ));

      await db.deleteWallet(walletId);

      final allWallets = await db.getWallets();
      final storedWallet = allWallets.firstWhere((w) => w.id == walletId);
      final activeWallets = await db.getActiveWallets();
      expect(storedWallet.isArchived, isTrue);
      expect(activeWallets.any((w) => w.id == walletId), isFalse);
    });
  });
}
