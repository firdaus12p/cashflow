// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          initialReminderPreferences: ReminderPreferences(),
          persistHomeHeroPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('Quick Menu Home — keberadaan dan isi', () {
    testWidgets('quick menu tampil di Home tab', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('home_quick_menu')), findsOneWidget);
    });

    testWidgets('quick menu berada di bawah saldo dan di atas analisa',
        (tester) async {
      await pumpApp(tester);

      final balanceY =
          tester.getCenter(find.byKey(const Key('home_balance_title'))).dy;
      final quickMenuY =
          tester.getCenter(find.byKey(const Key('home_quick_menu'))).dy;
      final analyticsY = tester.getCenter(find.text('Analisa Keuangan')).dy;

      expect(quickMenuY, greaterThan(balanceY));
      expect(quickMenuY, lessThan(analyticsY));
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
          matching: find.text('Pos keu..'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu berisi item Badge', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Badge'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu berisi item Pengingat', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Pengingat'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quick menu berisi item Reset Data', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Reset Data'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('item Reset Data punya key quick_menu_reset_data',
        (tester) async {
      await pumpApp(tester);

      expect(
        find.byKey(const Key('quick_menu_reset_data')),
        findsOneWidget,
      );
    });

    testWidgets('quick menu bisa digeser horizontal', (tester) async {
      await pumpApp(tester);

      final scrollable = find.descendant(
        of: find.byKey(const Key('home_quick_menu')),
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
      );
      expect(scrollable, findsOneWidget);
    });

    testWidgets('semua item quick menu punya ukuran kartu yang seragam',
        (tester) async {
      await pumpApp(tester);

      final dompetSize =
          tester.getSize(find.byKey(const Key('quick_menu_dompet')));
      final hutangSize =
          tester.getSize(find.byKey(const Key('quick_menu_hutang_piutang')));
      final posSize =
          tester.getSize(find.byKey(const Key('quick_menu_pos_keuangan')));
      final pengingatSize =
          tester.getSize(find.byKey(const Key('quick_menu_pengingat')));
      final badgeSize =
          tester.getSize(find.byKey(const Key('quick_menu_badge_pencapaian')));
      final resetSize =
          tester.getSize(find.byKey(const Key('quick_menu_reset_data')));

      expect(hutangSize.width, dompetSize.width);
      expect(posSize.width, dompetSize.width);
      expect(pengingatSize.width, dompetSize.width);
      expect(badgeSize.width, dompetSize.width);
      expect(resetSize.width, dompetSize.width);
      expect(hutangSize.height, dompetSize.height);
      expect(posSize.height, dompetSize.height);
      expect(pengingatSize.height, dompetSize.height);
      expect(badgeSize.height, dompetSize.height);
      expect(resetSize.height, dompetSize.height);
    });

    testWidgets('label quick menu panjang tetap satu baris dengan ellipsis',
        (tester) async {
      await pumpApp(tester);

      final posLabel = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('quick_menu_pos_keuangan')),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Pos keu..',
          ),
        ),
      );

      expect(posLabel.maxLines, 1);
      expect(posLabel.overflow, TextOverflow.ellipsis);
    });
  });

  group('Phase 10 — filter layout dan ikon', () {
    testWidgets('filter wallet berada di bawah filter Harian Bulanan Tahunan',
        (tester) async {
      await pumpApp(tester);

      final periodFilterY = tester.getCenter(find.text('Harian')).dy;
      final walletFilterY =
          tester.getCenter(find.byKey(const Key('wallet_filter_row'))).dy;

      expect(walletFilterY, greaterThan(periodFilterY));
    });

    testWidgets('filter Home menampilkan ikon pada Harian Bulanan Tahunan',
        (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.calendar_view_month_outlined), findsOneWidget);
      expect(find.byIcon(Icons.date_range_outlined), findsOneWidget);
    });
  });

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

    testWidgets('Beranda tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Beranda'),
        ),
        findsNothing,
      );
    });

    testWidgets('Target Tabungan tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Target Tabungan'),
        ),
        findsNothing,
      );
    });

    testWidgets('Wishlist Belanja tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Wishlist Belanja'),
        ),
        findsNothing,
      );
    });

    testWidgets('Tambah Transaksi tidak ada di quick menu', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('home_quick_menu')),
          matching: find.text('Tambah Transaksi'),
        ),
        findsNothing,
      );
    });
  });
}
