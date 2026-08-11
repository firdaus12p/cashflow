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
