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
  Wallet(
    id: 3,
    name: 'Bank',
    iconKey: 'bank',
    createdDate: _now,
    updatedDate: _now,
  ),
  Wallet(
    id: 4,
    name: 'Tabungan',
    iconKey: 'savings',
    createdDate: _now,
    updatedDate: _now,
  ),
];

void main() {
  Future<void> _pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> _pumpDompetPage(
    WidgetTester tester, {
    List<Wallet>? initialWallets,
    Future<int> Function(Wallet)? transactionCountForWallet,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DompetPage(
          initialWallets: initialWallets,
          transactionCountForWallet: transactionCountForWallet,
        ),
      ),
    );
    await _pumpUi(tester);
  }

  group('DompetPage — tampilan dan interaksi', () {
    testWidgets('DompetPage menampilkan wallet_list ketika ada data',
        (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.byKey(const Key('wallet_list')), findsOneWidget);
    });

    testWidgets('DompetPage menampilkan nama wallet', (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);
    });

    testWidgets('DompetPage punya tombol tambah dompet (FAB)', (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.byKey(const Key('dompet_fab')), findsOneWidget);
    });

    testWidgets('DompetPage punya tombol edit untuk setiap wallet',
        (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.byKey(const Key('wallet_edit_btn')), findsWidgets);
    });

    testWidgets('form tambah dompet muncul setelah tap FAB', (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      await tester.tap(find.byKey(const Key('dompet_fab')));
      await _pumpUi(tester);

      expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
      expect(find.byKey(const Key('wallet_save_btn')), findsOneWidget);
      expect(find.byKey(const Key('wallet_icon_cash')), findsOneWidget);
    });

    testWidgets('sheet tambah dompet menghormati inset bawah sistem',
        (tester) async {
      const mediaQueryData = MediaQueryData(
        size: Size(400, 800),
        viewPadding: EdgeInsets.only(bottom: 24),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: mediaQueryData,
          child: MaterialApp(
            home: DompetPage(initialWallets: _fakeWallets),
          ),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.byKey(const Key('dompet_fab')));
      await tester.pumpAndSettle();

      final saveButtonRect = tester.getRect(
        find.byKey(const Key('wallet_save_btn')),
      );
      expect(
        saveButtonRect.bottom,
        lessThanOrEqualTo(
          mediaQueryData.size.height - mediaQueryData.viewPadding.bottom,
        ),
      );
    });

    testWidgets('form edit dompet muncul setelah tap tombol edit',
        (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      await tester.tap(find.byKey(const Key('wallet_edit_btn')).first);
      await _pumpUi(tester);

      expect(find.text('Edit Dompet'), findsOneWidget);
      expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
    });

    testWidgets('DompetPage merender ikon dari iconKey tersimpan',
        (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.byIcon(Icons.payments_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone_android_outlined), findsWidgets);
    });

    testWidgets('DompetPage menampilkan empty state bila tidak ada wallet',
        (tester) async {
      await _pumpDompetPage(tester, initialWallets: const []);

      expect(find.text('Belum ada dompet'), findsOneWidget);
      expect(find.byKey(const Key('wallet_list')), findsNothing);
    });
  });

  group('BR-04 — warning flow arsip dompet berhistori', () {
    testWidgets('tombol arsip tersedia untuk setiap wallet', (tester) async {
      await _pumpDompetPage(tester, initialWallets: _fakeWallets);

      expect(find.byKey(const Key('wallet_archive_btn')), findsWidgets);
    });

    testWidgets('arsip dompet berhistori menampilkan warning dialog',
        (tester) async {
      Future<int> hasHistory(Wallet wallet) =>
          Future.value(wallet.id == 1 ? 1 : 0);

      await _pumpDompetPage(
        tester,
        initialWallets: _fakeWallets,
        transactionCountForWallet: hasHistory,
      );

      await tester.tap(find.byKey(const Key('wallet_archive_btn')).first);
      await _pumpUi(tester);

      expect(find.byKey(const Key('wallet_archive_warning')), findsOneWidget);
    });
  });
}
