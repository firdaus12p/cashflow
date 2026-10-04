// A bucket that went below zero after a confirmed correction is shown in red.
import 'package:cashflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final now = DateTime(2026, 9, 1);

  setUp(mockTestFontAssets);

  Future<Color?> balanceColor(WidgetTester tester, double balance) async {
    await tester.pumpWidget(MaterialApp(
      home: PosKeuanganPage(
        initialWallets: [
          Wallet(id: 1, name: 'Cash', createdDate: now, updatedDate: now),
        ],
        initialBucketSystemEnabled: true,
        initialBuckets: [
          FinancialBucket(
            id: 1,
            name: 'Jajan',
            walletId: 1,
            allocationPercentage: 100,
            currentBalance: balance,
            createdDate: now,
            updatedDate: now,
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final text = tester.widget<Text>(find.byKey(const Key('bucket_balance_text')));
    return text.style?.color;
  }

  testWidgets('saldo pos minus tampil merah', (tester) async {
    expect(await balanceColor(tester, -60000), AppPalette.textDanger);
    expect(find.text('Rp -60.000'), findsOneWidget);
  });

  testWidgets('saldo pos nol atau positif tetap warna biasa', (tester) async {
    expect(await balanceColor(tester, 0), AppPalette.textPrimary);
  });
}
