// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cashflow/data/database/database_helper.dart';

const _defaultWalletNames = ['Cash', 'E-Wallet', 'Bank', 'Tabungan'];

const _tableResetOrder = [
  'transaction_bucket_allocations',
  'bucket_transfers',
  'debt_payments',
  'debts',
  'financial_buckets',
  'transactions',
  'saving_goals',
  'wishlist',
  'badges',
  'app_preferences',
  'wallets',
];

int _isolatedDatabaseCounter = 0;
bool _databaseFactoryConfigured = false;

void _configureTestDatabaseFactory() {
  if (_databaseFactoryConfigured) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _databaseFactoryConfigured = true;
}

Future<void> initializeSharedTestDatabase() async {
  _configureTestDatabaseFactory();
  DatabaseHelper.overrideDatabasePath(':memory:');
  await DatabaseHelper().database;
}

Future<String> initializeIsolatedTestDatabase({
  String prefix = 'cashflow_test',
}) async {
  _configureTestDatabaseFactory();

  final dbPath = p.join(
    Directory.systemTemp.path,
    '${prefix}_${_isolatedDatabaseCounter++}.db',
  );
  DatabaseHelper.overrideDatabasePath(dbPath);
  await DatabaseHelper().database;
  return dbPath;
}

Future<void> resetSharedTestDatabase() async {
  final db = await DatabaseHelper().database;

  await db.transaction((txn) async {
    for (final table in _tableResetOrder) {
      await txn.delete(table);
    }

    await txn.execute('DELETE FROM sqlite_sequence');

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final name in _defaultWalletNames) {
      await txn.insert('wallets', {
        'name': name,
        'isArchived': 0,
        'createdDate': now,
        'updatedDate': now,
      });
    }
  });
}

Future<void> disposeSharedTestDatabase() async {
  try {
    await DatabaseHelper.closeDatabase().timeout(
      const Duration(milliseconds: 250),
    );
  } on TimeoutException {
    DatabaseHelper.overrideDatabasePath(':memory:');
  }
}

Future<void> disposeIsolatedTestDatabase(String dbPath) async {
  try {
    await DatabaseHelper.closeDatabase().timeout(
      const Duration(milliseconds: 250),
    );
  } on TimeoutException {
    DatabaseHelper.overrideDatabasePath(dbPath);
  }

  for (final suffix in ['', '-journal', '-shm', '-wal']) {
    final file = File('$dbPath$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
