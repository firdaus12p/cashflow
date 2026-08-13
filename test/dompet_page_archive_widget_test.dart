// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:cashflow/features/wallets/presentation/dompet_page.dart';

final _now = DateTime(2026);
final _fakeWallets = [
  Wallet(
    id: 1,
    name: 'Cash',
    iconKey: 'cash',
    createdDate: _now,
    updatedDate: _now,
  ),
  Wallet(
    id: 2,
    name: 'E-Wallet',
    iconKey: 'e_wallet',
    createdDate: _now,
    updatedDate: _now,
  ),
];

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DompetPage(
          initialWallets: _fakeWallets,
          transactionCountForWallet: (_) => Future.value(0),
          deleteWalletById: (_) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('hapus dompet tanpa histori tidak menampilkan warning',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('wallet_delete_btn')).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet_delete_warning')), findsNothing);
  });
}
