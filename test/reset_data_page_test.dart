// Widget tests for ResetDataPage and its quick menu entry.
// Tests verify: halaman penuh render dengan scope reset, dialog konfirmasi,
// dan callback seam yang dipakai shell untuk reload post-reset.

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/reset/presentation/reset_data_page.dart';

void main() {
  // Helper: pump ResetDataPage dengan seam injectable.
  Future<void> pumpResetPage(
    WidgetTester tester, {
    List<String> resetLog = const [],
    List<String> completeLog = const [],
  }) async {
    final mutableResetLog = [...resetLog];
    final mutableCompleteLog = [...completeLog];

    await tester.pumpWidget(
      MaterialApp(
        home: ResetDataPage(
          resetHandler: () async => mutableResetLog.add('reset'),
          onResetComplete: () => mutableCompleteLog.add('complete'),
        ),
      ),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // Render & struktur halaman
  // ---------------------------------------------------------------------------

  group('ResetDataPage — render dan struktur', () {
    testWidgets('halaman render dengan key page_reset_data', (tester) async {
      await pumpResetPage(tester);

      expect(find.byKey(const Key('page_reset_data')), findsOneWidget);
    });

    testWidgets(
        'halaman menampilkan teks peringatan tentang penghapusan permanen',
        (tester) async {
      await pumpResetPage(tester);

      // Setidaknya ada satu teks yang menyebutkan penghapusan atau permanen
      final hasWarning =
          find.textContaining('permanen').evaluate().isNotEmpty ||
              find.textContaining('dihapus').evaluate().isNotEmpty ||
              find.textContaining('hilang').evaluate().isNotEmpty;
      expect(hasWarning, isTrue);
    });

    testWidgets('halaman menampilkan CTA tombol reset', (tester) async {
      await pumpResetPage(tester);

      expect(
        find.byKey(const Key('reset_data_cta_button')),
        findsOneWidget,
      );
    });

    testWidgets('judul halaman adalah Reset Data', (tester) async {
      await pumpResetPage(tester);

      expect(find.text('Reset Data'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Dialog konfirmasi (BR-28)
  // ---------------------------------------------------------------------------

  group('ResetDataPage — dialog konfirmasi', () {
    testWidgets('tap CTA memunculkan dialog konfirmasi', (tester) async {
      await pumpResetPage(tester);

      await tester.tap(find.byKey(const Key('reset_data_cta_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_confirm_dialog')), findsOneWidget);
    });

    testWidgets('dialog konfirmasi berisi tombol Batal dan tombol Reset',
        (tester) async {
      await pumpResetPage(tester);

      await tester.tap(find.byKey(const Key('reset_data_cta_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_dialog_cancel')), findsOneWidget);
      expect(find.byKey(const Key('reset_dialog_confirm')), findsOneWidget);
    });

    testWidgets('tap Batal menutup dialog tanpa memanggil reset',
        (tester) async {
      final resetLog = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ResetDataPage(
            resetHandler: () async => resetLog.add('reset'),
            onResetComplete: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('reset_data_cta_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reset_dialog_cancel')));
      await tester.pumpAndSettle();

      // Dialog tutup
      expect(find.byKey(const Key('reset_confirm_dialog')), findsNothing);
      // resetHandler tidak dipanggil
      expect(resetLog, isEmpty);
    });

    testWidgets('tap Reset memanggil resetHandler dan onResetComplete',
        (tester) async {
      final resetLog = <String>[];
      final completeLog = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ResetDataPage(
            resetHandler: () async => resetLog.add('reset'),
            onResetComplete: () => completeLog.add('complete'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('reset_data_cta_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reset_dialog_confirm')));
      await tester.pumpAndSettle();

      expect(resetLog, ['reset']);
      expect(completeLog, ['complete']);
    });
  });
}
