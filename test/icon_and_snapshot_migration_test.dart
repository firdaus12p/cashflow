// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:cashflow/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // iconKey backward-compat: record lama (hanya emoji, iconKey null) tidak
  // boleh menghasilkan icon kosong di UI.
  // ---------------------------------------------------------------------------

  group('SavingGoal.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final goal = SavingGoal(
        name: 'Liburan',
        targetAmount: 5000000,
        emoji: '✈️',
        iconKey: 'flight',
        createdDate: DateTime(2026, 1, 1),
      );
      // gap: SavingGoal.effectiveIcon belum ada — ditambahkan di Task 2.4
      expect(goal.effectiveIcon, 'flight');
    });

    test('falls back to emoji when iconKey is null', () {
      final goal = SavingGoal(
        name: 'Liburan',
        targetAmount: 5000000,
        emoji: '✈️',
        createdDate: DateTime(2026, 1, 1),
      );
      expect(goal.effectiveIcon, '✈️');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Dana Darurat',
        'targetAmount': 10000000.0,
        'currentAmount': 2000000.0,
        'emoji': '🛡️',
        'iconKey': null,
        'createdDate': DateTime(2025, 6, 1).millisecondsSinceEpoch,
        'targetDate': null,
      };
      final goal = SavingGoal.fromMap(map);
      expect(goal.effectiveIcon, '🛡️',
          reason: 'record lama tanpa iconKey harus fallback ke emoji');
    });

    test('fromMap with iconKey set returns iconKey', () {
      final map = {
        'id': 2,
        'name': 'Rumah',
        'targetAmount': 500000000.0,
        'currentAmount': 0.0,
        'emoji': '🏠',
        'iconKey': 'home',
        'createdDate': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'targetDate': null,
      };
      final goal = SavingGoal.fromMap(map);
      expect(goal.effectiveIcon, 'home');
    });
  });

  group('WishlistItem.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final item = WishlistItem(
        name: 'Laptop',
        price: 15000000,
        emoji: '💻',
        iconKey: 'laptop',
        createdDate: DateTime(2026, 1, 1),
      );
      expect(item.effectiveIcon, 'laptop');
    });

    test('falls back to emoji when iconKey is null', () {
      final item = WishlistItem(
        name: 'Sepatu',
        price: 500000,
        emoji: '👟',
        createdDate: DateTime(2026, 1, 1),
      );
      expect(item.effectiveIcon, '👟');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Tas',
        'price': 800000.0,
        'emoji': '👜',
        'iconKey': null,
        'priority': 'high',
        'createdDate': DateTime(2025, 9, 1).millisecondsSinceEpoch,
      };
      final item = WishlistItem.fromMap(map);
      expect(item.effectiveIcon, '👜');
    });
  });

  group('UserBadge.effectiveIcon fallback', () {
    test('returns iconKey when set', () {
      final badge = UserBadge(
        name: 'Hemat Bulan Ini',
        description: 'Berhasil hemat',
        emoji: '🏆',
        iconKey: 'emoji_events',
        earnedDate: DateTime(2026, 1, 1),
        type: 'saving',
      );
      expect(badge.effectiveIcon, 'emoji_events');
    });

    test('falls back to emoji when iconKey is null', () {
      final badge = UserBadge(
        name: 'Hemat',
        description: 'Hemat',
        emoji: '🏆',
        earnedDate: DateTime(2026, 1, 1),
        type: 'saving',
      );
      expect(badge.effectiveIcon, '🏆');
    });

    test('fromMap with null iconKey falls back to emoji', () {
      final map = {
        'id': 1,
        'name': 'Juara Hemat',
        'description': 'Berhasil',
        'emoji': '⭐',
        'iconKey': null,
        'earnedDate': DateTime(2025, 8, 1).millisecondsSinceEpoch,
        'type': 'saving',
      };
      final badge = UserBadge.fromMap(map);
      expect(badge.effectiveIcon, '⭐');
    });
  });

  // ---------------------------------------------------------------------------
  // walletNameSnapshot: transaksi menyimpan snapshot nama dompet agar histori
  // tetap terbaca setelah dompet diarsipkan atau dihapus.
  // ---------------------------------------------------------------------------

  group('walletNameSnapshot persistence', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cashflow_snap_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('snapshot tersimpan dan terbaca setelah wallet diarsipkan', () async {
      DatabaseHelper.overrideDatabasePath(p.join(tempDir.path, 'snap_test.db'));
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Insert wallet dan transaksi dengan snapshot
      final walletId = await dbHelper.insertWallet(Wallet(
        name: 'Dompet Spesial',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 1),
      ));

      final txId = await db.insert('transactions', {
        'type': 'expense',
        'amount': 100000.0,
        'category': 'Makanan',
        'description': 'Makan siang',
        'date': DateTime(2026, 6, 1).millisecondsSinceEpoch,
        'wallet': 'Dompet Spesial',
        'walletId': walletId,
        'walletNameSnapshot': 'Dompet Spesial',
        'affectsBalance': 1,
      });

      // Arsipkan wallet — nama aktif berubah
      await dbHelper.archiveWallet(walletId);

      // Snapshot pada transaksi harus tetap terbaca
      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [txId],
      );
      expect(rows.first['walletNameSnapshot'], 'Dompet Spesial',
          reason: 'snapshot harus tetap ada setelah wallet diarsipkan');
    });

    test('transaksi tanpa snapshot (data lama) tidak error saat dibaca',
        () async {
      DatabaseHelper.overrideDatabasePath(
          p.join(tempDir.path, 'snap_legacy.db'));
      final db = await DatabaseHelper().database;

      // Masukkan transaksi lama tanpa snapshot (default '')
      await db.insert('transactions', {
        'type': 'income',
        'amount': 3000000.0,
        'category': 'Gaji',
        'description': 'Gaji bulanan',
        'date': DateTime(2026, 6, 1).millisecondsSinceEpoch,
        'wallet': 'Cash',
      });

      final rows = await db.query('transactions');
      final tx = Transaction.fromMap(rows.first);
      expect(tx.walletNameSnapshot, '',
          reason: 'record lama tanpa snapshot harus default ke string kosong');
      expect(tx.wallet, 'Cash');
    });
  });
}
