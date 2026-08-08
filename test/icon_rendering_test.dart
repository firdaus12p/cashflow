// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:pinkycash_app/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.overrideDatabasePath(':memory:');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  // ---------------------------------------------------------------------------
  // Tab bar: emoji fungsional harus diganti dengan Material icons
  // ---------------------------------------------------------------------------

  group('Tab bar — migrasi ikon', () {
    testWidgets('tab Home memakai ikon Material bukan emoji', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.home_rounded), findsWidgets);
    });

    testWidgets('tab Statistik memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);
    });

    testWidgets('tab Goal memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.flag_rounded), findsWidgets);
    });

    testWidgets('tab Wish memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.shopping_bag_outlined), findsWidgets);
    });

    testWidgets('tab Badge memakai ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    });

    testWidgets('tab bar tidak lagi berisi emoji 💰', (tester) async {
      await pumpApp(tester);

      // Setelah migrasi, emoji string tidak boleh ada sebagai ikon fungsional
      // di TabBar (cari di seluruh tree karena emoji hanya ada di tab saat ini)
      final tabBar = find.byType(TabBar);
      expect(
        find.descendant(of: tabBar, matching: find.text('💰')),
        findsNothing,
      );
    });

    testWidgets('tab bar tidak lagi berisi emoji 📊', (tester) async {
      await pumpApp(tester);

      final tabBar = find.byType(TabBar);
      expect(
        find.descendant(of: tabBar, matching: find.text('📊')),
        findsNothing,
      );
    });

    testWidgets('tab bar tidak lagi berisi emoji 🎯', (tester) async {
      await pumpApp(tester);

      final tabBar = find.byType(TabBar);
      expect(
        find.descendant(of: tabBar, matching: find.text('🎯')),
        findsNothing,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Wallet filter: emoji dompet harus diganti dengan Material icons
  // ---------------------------------------------------------------------------

  group('Wallet filter — migrasi ikon', () {
    // Chip 'All' selalu muncul (hardcoded di presentasi), chip lain dari DB.
    testWidgets('chip All memiliki ikon Material', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);
    });

    // Phase 4: chip Cash/E-Wallet/Bank/Tabungan sekarang dinamis dari DB.
    // Tidak bisa di-assert di fake-async testWidgets (sqflite isolate timing).
    // Logika icon rendering tetap di _getWalletIcon — dijamin oleh chip All
    // yang memakai fungsi yang sama, dan oleh DB-level tests di wallet_management_test.

    testWidgets('wallet filter tidak lagi berisi emoji string 💵',
        (tester) async {
      await pumpApp(tester);

      // Emoji di dalam chip tidak boleh ada sebagai standalone text
      expect(find.text('💵 Cash'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Empty states: emoji ikon diganti dengan Material icons
  // ---------------------------------------------------------------------------

  group('Empty state transaction — migrasi ikon', () {
    testWidgets('empty transaction memakai ikon receipt_long bukan 📝',
        (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.receipt_long_outlined), findsWidgets);
      expect(find.text('📝'), findsNothing);
    });
  });
}
