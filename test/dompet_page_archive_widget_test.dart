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
  for (final referenceCount in [0, 2]) {
    testWidgets(
        'active owned buckets reject wallet removal with $referenceCount references',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: DompetPage(
        initialWallets: _fakeWallets,
        transactionCountForWallet: (_) async => referenceCount,
        deleteWalletById: (_) async =>
            throw StateError('private database detail'),
      )));
      await tester.tap(find.byKey(const Key('wallet_delete_btn')).first);
      await tester.pumpAndSettle();
      if (referenceCount > 0) {
        await tester.tap(find.byKey(const Key('wallet_remove_btn')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Cash'), findsOneWidget);
      expect(
          find.text(
              'Dompet masih memiliki pos aktif. Selesaikan pos tersebut sebelum menghapus dompet.'),
          findsOneWidget);
      expect(find.textContaining('private database detail'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
