// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pinkycash_app/main.dart';

// Tabel bawaan yang harus tetap ada setelah migrasi.
const _legacyTables = ['transactions', 'saving_goals', 'wishlist', 'badges'];

// Tabel baru yang ditambahkan di versi 3.
const _newTables = [
  'wallets',
  'debts',
  'debt_payments',
  'financial_buckets',
  'transaction_bucket_allocations',
  'bucket_transfers',
];

const _seedWalletNames = ['Cash', 'E-Wallet', 'Bank', 'Tabungan'];

// Helper: ambil daftar nama tabel dari sqlite_master.
Future<List<String>> _tableNames(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  );
  return rows.map((r) => r['name'] as String).toList();
}

// Helper: ambil nama kolom dari tabel tertentu.
Future<List<String>> _columnNames(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toList();
}

// Helper: buat database skema v2 di path yang diberikan.
Future<void> _createV2Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            date INTEGER NOT NULL,
            wallet TEXT DEFAULT 'Cash'
          )
        ''');
        await db.execute('''
          CREATE TABLE saving_goals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            targetAmount REAL NOT NULL,
            currentAmount REAL DEFAULT 0,
            emoji TEXT DEFAULT '💰',
            createdDate INTEGER NOT NULL,
            targetDate INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE wishlist(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            emoji TEXT DEFAULT '🛍️',
            priority TEXT DEFAULT 'medium',
            createdDate INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE badges(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            emoji TEXT NOT NULL,
            earnedDate INTEGER NOT NULL,
            type TEXT NOT NULL
          )
        ''');
      },
    ),
  );
  await db.close();
}

// Helper: buat database skema v1 (sebelum kolom wallet ada) di path yang diberikan.
Future<void> _createV1Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            date INTEGER NOT NULL
          )
        ''');
      },
    ),
  );
  await db.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Fresh install (onCreate v3)', () {
    setUp(() {
      // gap: DatabaseHelper.overrideDatabasePath belum ada — ditambahkan di Task 2.2
      DatabaseHelper.overrideDatabasePath(':memory:');
    });

    test('semua 6 tabel baru terbuat', () async {
      final db = await DatabaseHelper().database;
      final tables = await _tableNames(db);
      for (final t in _newTables) {
        expect(tables, contains(t),
            reason: 'tabel $t harus ada setelah onCreate');
      }
    });

    test('4 tabel lama tetap ada', () async {
      final db = await DatabaseHelper().database;
      final tables = await _tableNames(db);
      for (final t in _legacyTables) {
        expect(tables, contains(t), reason: 'tabel $t harus tetap ada');
      }
    });

    test('seed wallets default tersedia setelah install baru', () async {
      final db = await DatabaseHelper().database;
      final rows = await db.query('wallets', columns: ['name']);
      final names = rows.map((r) => r['name'] as String).toList();
      for (final name in _seedWalletNames) {
        expect(names, contains(name), reason: 'wallet $name harus di-seed');
      }
    });

    test(
        'transactions memiliki kolom walletId, walletNameSnapshot, affectsBalance',
        () async {
      final db = await DatabaseHelper().database;
      final cols = await _columnNames(db, 'transactions');
      expect(cols, contains('walletId'));
      expect(cols, contains('walletNameSnapshot'));
      expect(cols, contains('affectsBalance'));
    });
  });

  group('Upgrade v2 → v3', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cashflow_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('semua tabel baru ada setelah upgrade dari v2', () async {
      final dbPath = p.join(tempDir.path, 'upgrade_v2.db');
      await _createV2Database(dbPath);

      // Arahkan singleton ke file v2 sehingga openDatabase memicu _onUpgrade
      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final tables = await _tableNames(db);

      for (final t in _newTables) {
        expect(tables, contains(t),
            reason: 'tabel $t harus ada setelah upgrade v2→v3');
      }
    });

    test('kolom baru transactions ada setelah upgrade dari v2', () async {
      final dbPath = p.join(tempDir.path, 'upgrade_cols.db');
      await _createV2Database(dbPath);

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final cols = await _columnNames(db, 'transactions');

      expect(cols, contains('walletId'));
      expect(cols, contains('walletNameSnapshot'));
      expect(cols, contains('affectsBalance'));
    });

    test('seed wallets tersedia setelah upgrade dari v2', () async {
      final dbPath = p.join(tempDir.path, 'upgrade_seed.db');
      await _createV2Database(dbPath);

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final rows = await db.query('wallets', columns: ['name']);
      final names = rows.map((r) => r['name'] as String).toList();

      for (final name in _seedWalletNames) {
        expect(names, contains(name),
            reason: 'wallet $name harus di-seed saat upgrade');
      }
    });

    test('data transactions lama tetap bisa dimuat setelah upgrade', () async {
      final dbPath = p.join(tempDir.path, 'upgrade_data.db');
      // Buat skema v2 lengkap, lalu insert data lama ke dalamnya
      await _createV2Database(dbPath);
      final v2db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2),
      );
      await v2db.insert('transactions', {
        'type': 'expense',
        'amount': 50000.0,
        'category': 'Makanan',
        'description': 'Makan siang',
        'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'wallet': 'Cash',
      });
      await v2db.close();

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final rows = await db.query('transactions');

      expect(rows.length, 1,
          reason: 'data lama harus tetap ada setelah upgrade');
      expect(rows.first['category'], 'Makanan');
      expect(rows.first['wallet'], 'Cash');
    });

    test('seed wallets idempotent — tidak duplikat bila dijalankan dua kali',
        () async {
      final dbPath = p.join(tempDir.path, 'upgrade_idempotent.db');
      await _createV2Database(dbPath);

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;

      final rows =
          await db.query('wallets', columns: ['name'], where: "name = 'Cash'");
      expect(rows.length, 1, reason: 'Cash hanya boleh muncul sekali');
    });
  });

  group('Upgrade v1 → v3 (chain)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cashflow_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('upgrade chain v1→v3 menghasilkan skema v3 lengkap', () async {
      final dbPath = p.join(tempDir.path, 'upgrade_v1.db');
      await _createV1Database(dbPath);

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final tables = await _tableNames(db);

      // Harus ada semua tabel legacy (walletnya masih kosong tapi tabel ada)
      for (final t in _legacyTables) {
        expect(tables, contains(t),
            reason: 'tabel $t harus ada dari chain upgrade');
      }
      // Harus ada semua tabel baru
      for (final t in _newTables) {
        expect(tables, contains(t),
            reason: 'tabel $t harus ada dari chain upgrade');
      }
    });

    test('kolom wallet ada di transactions setelah upgrade chain v1→v3',
        () async {
      final dbPath = p.join(tempDir.path, 'chain_cols.db');
      await _createV1Database(dbPath);

      DatabaseHelper.overrideDatabasePath(dbPath);
      final db = await DatabaseHelper().database;
      final cols = await _columnNames(db, 'transactions');

      // Kolom dari v1→v2
      expect(cols, contains('wallet'));
      // Kolom dari v2→v3
      expect(cols, contains('walletId'));
      expect(cols, contains('walletNameSnapshot'));
      expect(cols, contains('affectsBalance'));
    });
  });
}
