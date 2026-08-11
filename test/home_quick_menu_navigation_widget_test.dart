// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialWallets: [],
          initialBuckets: [],
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          persistHomeHeroPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('BR-02 — quick menu navigation integration', () {
    testWidgets('tap Dompet membuka DompetPage', (tester) async {
      await pumpApp(tester);

      await tester.ensureVisible(find.byKey(const Key('quick_menu_dompet')));
      await tester.tap(find.byKey(const Key('quick_menu_dompet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_dompet')), findsOneWidget);
    });

    testWidgets('tap Hutang/Piutang membuka HutangPiutangPage', (tester) async {
      await pumpApp(tester);

      await tester
          .ensureVisible(find.byKey(const Key('quick_menu_hutang_piutang')));
      await tester.tap(find.byKey(const Key('quick_menu_hutang_piutang')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_hutang_piutang')), findsOneWidget);
    });

    testWidgets('tap Pos Keuangan membuka PosKeuanganPage', (tester) async {
      await pumpApp(tester);

      await tester
          .ensureVisible(find.byKey(const Key('quick_menu_pos_keuangan')));
      await tester.tap(find.byKey(const Key('quick_menu_pos_keuangan')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_pos_keuangan')), findsOneWidget);
    });

    testWidgets('tap Badge membuka BadgePencapaianPage', (tester) async {
      await pumpApp(tester);

      await tester
          .ensureVisible(find.byKey(const Key('quick_menu_badge_pencapaian')));
      await tester.tap(find.byKey(const Key('quick_menu_badge_pencapaian')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_badge_pencapaian')), findsOneWidget);
      expect(find.text('Badge & Pencapaian'), findsWidgets);
    });
  });
}
