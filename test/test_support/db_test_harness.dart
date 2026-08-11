// ignore_for_file: depend_on_referenced_packages

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

Future<void> initializeSharedTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.overrideDatabasePath(':memory:');
  await DatabaseHelper().database;
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
  await DatabaseHelper.closeDatabase();
}
