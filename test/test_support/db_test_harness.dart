// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cashflow/data/database/database_helper.dart';

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

bool _databaseFactoryConfigured = false;

void mockTestFontAssets() {
  // These are behavioral tests: supply empty font assets and use the test font.
  final fontAssets = {
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'Poppins-$weight.ttf': [
        {'asset': 'Poppins-$weight.ttf'},
      ],
  };
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final key = const StringCodec().decodeMessage(message);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(fontAssets);
    }
    if (fontAssets.containsKey(key)) return ByteData(0);
    return null;
  });
}

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

  final directory = await Directory.systemTemp.createTemp('${prefix}_');
  final dbPath = p.join(directory.path, 'test.db');
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
  });

  await DatabaseHelper.closeDatabase();
  DatabaseHelper.overrideDatabasePath(':memory:');
  await DatabaseHelper().database;
}

Future<void> disposeSharedTestDatabase() async {
  await DatabaseHelper.closeDatabase();
}

Future<void> disposeIsolatedTestDatabase(String dbPath) async {
  await DatabaseHelper.closeDatabase();

  for (final suffix in ['', '-journal', '-shm', '-wal']) {
    final file = File('$dbPath$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
  await Directory(p.dirname(dbPath)).delete();
}
