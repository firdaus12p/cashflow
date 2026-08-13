// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/data/database/database_helper.dart';

import 'test_support/db_test_harness.dart';

const sourceTypePreferenceKey = 'homeBalanceSourceType';
const sourceIdPreferenceKey = 'homeBalanceSourceId';
const visibilityHiddenPreferenceKey = 'homeBalanceVisibilityHidden';

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

  test('app_preferences hero Home bisa dibaca kembali dari storage lokal',
      () async {
    final db = DatabaseHelper();

    await db.setAppPreference(sourceTypePreferenceKey, 'wallet');
    await db.setAppPreference(sourceIdPreferenceKey, '1');
    await db.setAppPreference(visibilityHiddenPreferenceKey, '1');

    final preferences = await db.getAppPreferences([
      sourceTypePreferenceKey,
      sourceIdPreferenceKey,
      visibilityHiddenPreferenceKey,
    ]);

    expect(preferences[sourceTypePreferenceKey], 'wallet');
    expect(preferences[sourceIdPreferenceKey], '1');
    expect(preferences[visibilityHiddenPreferenceKey], '1');
  });

  test('status mode pos bisa dibaca dan disimpan kembali dari storage lokal',
      () async {
    final db = DatabaseHelper();

    expect(await db.getBucketSystemEnabled(), isTrue);

    await db.setBucketSystemEnabled(false);
    expect(await db.getBucketSystemEnabled(), isFalse);

    await db.setBucketSystemEnabled(true);
    expect(await db.getBucketSystemEnabled(), isTrue);
  });
}
