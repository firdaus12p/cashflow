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

  group('Quick Menu Home — keberadaan dan isi', () {
    testWidgets('quick menu tampil di Home tab', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('home_quick_menu')), findsOneWidget);
    });

    testWidgets('quick menu berisi item Dompet', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Dompet'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu berisi item Hutang/Piutang', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Hutang/Piutang'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu berisi item Pos Keuangan', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Pos Keuangan'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu bisa digeser horizontal', (tester) async {
      await pumpApp(tester);

      // Quick menu harus memiliki SingleChildScrollView horizontal
      final scrollable = find.descendant(
        of: find.byKey(const Key('home_quick_menu')),
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
      );
      expect(scrollable, findsOneWidget);
    });
  });

  // BR-01: item quick menu tidak boleh menduplikasi bottom navigation
  group('BR-01 — tidak ada duplikat bottom nav di quick menu', () {
    testWidgets('Statistik tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Statistik'),
        ),
        findsNothing,
      );
    });

    testWidgets('Goal tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Goal'),
        ),
        findsNothing,
      );
    });

    testWidgets('Wish tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Wish'),
        ),
        findsNothing,
      );
    });

    testWidgets('Badge tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Badge'),
        ),
        findsNothing,
      );
    });
  });

  // BR-02: navigasi dari quick menu membuka halaman penuh, bukan bottom sheet
  group('BR-02 — navigasi quick menu membuka halaman penuh', () {
    testWidgets('tap Dompet membuka DompetPage', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('quick_menu_dompet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_dompet')), findsOneWidget);
    });

    testWidgets('tap Hutang/Piutang membuka HutangPiutangPage', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('quick_menu_hutang_piutang')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_hutang_piutang')), findsOneWidget);
    });

    testWidgets('tap Pos Keuangan membuka PosKeuanganPage', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('quick_menu_pos_keuangan')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_pos_keuangan')), findsOneWidget);
    });
  });
}
