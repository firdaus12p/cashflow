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
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          persistHomeHeroPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('Bottom shell — migrasi ikon', () {
    testWidgets('tab Beranda memakai ikon Material bukan emoji',
        (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.home_rounded), findsWidgets);
    });

    testWidgets('tab Statistik memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);
    });

    testWidgets('tab Target Tabungan memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.flag_rounded), findsWidgets);
    });

    testWidgets('tab Wishlist Belanja memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.shopping_bag_outlined), findsWidgets);
    });

    testWidgets('aksi tambah transaksi tengah memakai ikon Material',
        (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets('aksi tambah transaksi tengah tidak lagi memakai bubble ganda',
        (tester) async {
      await pumpApp(tester);

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      expect(fab.backgroundColor, Colors.transparent);
      expect(fab.elevation, 0);
      expect(fab.shape, isA<RoundedRectangleBorder>());
    });

    testWidgets('quick menu Badge memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.emoji_events_outlined), findsWidgets);
    });

    testWidgets('dock bawah tidak lagi berisi emoji 💰', (tester) async {
      await pumpApp(tester);

      final tabBar = find.byKey(const Key('bottom_nav_bar'));
      expect(
        find.descendant(of: tabBar, matching: find.text('💰')),
        findsNothing,
      );
    });

    testWidgets('dock bawah tidak lagi berisi emoji 📊', (tester) async {
      await pumpApp(tester);

      final tabBar = find.byKey(const Key('bottom_nav_bar'));
      expect(
        find.descendant(of: tabBar, matching: find.text('📊')),
        findsNothing,
      );
    });

    testWidgets('dock bawah tidak lagi berisi emoji 🎯', (tester) async {
      await pumpApp(tester);

      final tabBar = find.byKey(const Key('bottom_nav_bar'));
      expect(
        find.descendant(of: tabBar, matching: find.text('🎯')),
        findsNothing,
      );
    });
  });

  group('Wallet filter — migrasi ikon', () {
    testWidgets('chip All memiliki ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);
    });

    testWidgets('wallet filter tidak lagi berisi emoji string 💵',
        (tester) async {
      await pumpApp(tester);

      expect(find.text('💵 Cash'), findsNothing);
    });
  });

  group('Empty state transaction — migrasi ikon', () {
    testWidgets('empty transaction memakai ikon receipt_long bukan 📝',
        (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.receipt_long_outlined), findsWidgets);
      expect(find.text('📝'), findsNothing);
    });
  });
}
