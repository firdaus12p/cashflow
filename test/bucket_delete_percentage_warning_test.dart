// Deleting a bucket leaves the others below 100%; the dialog says so.
import 'package:cashflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final now = DateTime(2026, 9, 1);

  setUp(mockTestFontAssets);

  FinancialBucket bucket(int id, String name, double pct) => FinancialBucket(
        id: id,
        name: name,
        walletId: 1,
        allocationPercentage: pct,
        createdDate: now,
        updatedDate: now,
      );

  Future<void> openDeleteDialog(
    WidgetTester tester, {
    required bool bucketSystemEnabled,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: PosKeuanganPage(
        initialWallets: [
          Wallet(id: 1, name: 'Cash', createdDate: now, updatedDate: now),
        ],
        initialBucketSystemEnabled: bucketSystemEnabled,
        initialBuckets: [bucket(1, 'Jajan', 60), bucket(2, 'Tabungan', 40)],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final button = find.byKey(const Key('bucket_delete_btn')).first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('mode pos aktif: dialog menyebut sisa persentase pos lain',
      (tester) async {
    await openDeleteDialog(tester, bucketSystemEnabled: true);
    expect(find.byKey(const Key('bucket_delete_dialog')), findsOneWidget);
    expect(find.byKey(const Key('bucket_delete_percentage_note')), findsOneWidget);
    final note = tester
        .widget<Text>(find.byKey(const Key('bucket_delete_percentage_note')))
        .data!;
    expect(note, contains('tinggal 40%'));
    expect(note, contains('sampai 100%'));
  });

  testWidgets('mode pos mati: tidak ada catatan persentase', (tester) async {
    await openDeleteDialog(tester, bucketSystemEnabled: false);
    expect(find.byKey(const Key('bucket_delete_dialog')), findsOneWidget);
    expect(find.byKey(const Key('bucket_delete_percentage_note')), findsNothing);
  });
}
