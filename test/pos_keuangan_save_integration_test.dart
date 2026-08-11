// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  setUpAll(() async {
    await initializeSharedTestDatabase();
  });

  setUp(() async {
    await resetSharedTestDatabase();
  });

  tearDownAll(() async {
    await disposeSharedTestDatabase();
  });

  Future<void> _pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PosKeuanganPage(
          initialWallets: [
            Wallet(
              id: 1,
              name: 'Cash',
              createdDate: now,
              updatedDate: now,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> _pumpSheetFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets(
      'mengizinkan simpan pos bertahap selama total belum melebihi 100%',
      (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await _pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('bucket_name_field')),
      'Tabungan',
    );
    await tester.enterText(
      find.byKey(const Key('bucket_pct_field')),
      '30',
    );

    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await _pumpSheetFrames(tester);

    final savedBuckets = await DatabaseHelper().getFinancialBuckets();
    expect(savedBuckets, hasLength(1));
    expect(savedBuckets.single.name, 'Tabungan');
    expect(savedBuckets.single.allocationPercentage, 30);
    expect(
      find.text('Total persentase semua pos tidak boleh lebih dari 100%.'),
      findsNothing,
    );
  });
}
