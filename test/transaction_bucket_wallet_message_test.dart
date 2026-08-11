// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:cashflow/main.dart' show MainScreen;

// Widget-level validation: pesan dan affordance sheet transaksi utama.

void main() {
  const shortTimeout = Timeout(Duration(seconds: 10));
  final now = DateTime(2026, 8, 10);

  Future<void> _pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialTransactions: const [],
          initialAllTransactions: const [],
          initialWallets: [
            Wallet(
              id: 1,
              name: 'Cash',
              createdDate: now,
              updatedDate: now,
            ),
            Wallet(
              id: 2,
              name: 'Bank',
              createdDate: now,
              updatedDate: now,
            ),
          ],
          initialBuckets: [
            FinancialBucket(
              id: 11,
              name: 'Belanja Cash',
              walletId: 1,
              allocationPercentage: 60,
              currentBalance: 0,
              createdDate: now,
              updatedDate: now,
            ),
            FinancialBucket(
              id: 22,
              name: 'Belanja Bank',
              walletId: 2,
              allocationPercentage: 40,
              currentBalance: 0,
              createdDate: now,
              updatedDate: now,
            ),
          ],
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

  Future<void> _pumpSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets(
    'income lintas dompet menampilkan pesan validasi yang benar',
    (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await _pumpSheet(tester);

      await tester.tap(find.text('Pemasukan').last);
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.enterText(find.byType(TextField).last, 'Gaji lintas dompet');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);

      expect(
        find.text('Pilih bucket pemasukan dari satu dompet yang sama.'),
        findsOneWidget,
      );
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'sheet transaksi utama menampilkan drag handle dan opsi bucket expense income',
    (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await _pumpSheet(tester);

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
      expect(
        find.byKey(const Key('transaction_bucket_section')),
        findsOneWidget,
      );

      await tester.tap(find.text('Pemasukan').last);
      await _pumpSheet(tester);
      expect(find.byKey(const Key('income_bucket_selector')), findsOneWidget);

      await tester.tap(find.text('Pengeluaran').last);
      await _pumpSheet(tester);
      expect(find.byKey(const Key('expense_bucket_dropdown')), findsOneWidget);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'bottom nav memakai ikon dan teks yang lebih besar untuk keterbacaan',
    (tester) async {
      await _pumpHome(tester);

      final berandaIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('bottom_nav_beranda')),
          matching: find.byIcon(Icons.home_rounded),
        ),
      );
      final berandaLabel = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('bottom_nav_beranda')),
          matching: find.text('Beranda'),
        ),
      );

      expect(berandaIcon.size, 22);
      expect(berandaLabel.style?.fontSize, 10);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'keterangan kosong menampilkan pesan wajib sebelum save diproses',
    (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '125000');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);

      expect(
          find.byKey(const Key('transaction_sheet_feedback')), findsOneWidget);
      expect(find.text('Keterangan wajib diisi.'), findsOneWidget);
      expect(find.text('Tambah Transaksi 💰'), findsOneWidget);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'feedback transaksi hilang otomatis setelah sebentar',
    (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '125000');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await _pumpSheet(tester);

      expect(
          find.byKey(const Key('transaction_sheet_feedback')), findsOneWidget);
      expect(find.text('Keterangan wajib diisi.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));

      expect(find.byKey(const Key('transaction_sheet_feedback')), findsNothing);
      expect(find.text('Keterangan wajib diisi.'), findsNothing);
    },
    timeout: shortTimeout,
  );
}
