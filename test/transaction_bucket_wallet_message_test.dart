// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:cashflow/main.dart' show MainScreen;

import 'test_support/db_test_harness.dart';

// Widget-level validation: pesan dan affordance sheet transaksi utama.

void main() {
  const shortTimeout = Timeout(Duration(seconds: 10));
  final now = DateTime(2026, 8, 10);
  late String dbPath;

  setUp(() async {
    mockTestFontAssets();
    dbPath = await initializeIsolatedTestDatabase(
      prefix: 'transaction_bucket_wallet_message_test',
    );
  });

  tearDown(() async {
    await disposeIsolatedTestDatabase(dbPath);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

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
              allocationPercentage: 100,
              currentBalance: 0,
              createdDate: now,
              updatedDate: now,
            ),
            FinancialBucket(
              id: 22,
              name: 'Belanja Bank',
              walletId: 2,
              allocationPercentage: 100,
              currentBalance: 0,
              createdDate: now,
              updatedDate: now,
            ),
          ],
          initialBucketSystemEnabled: true,
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

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets(
    'income lintas dompet menampilkan helper dompet otomatis dan diblokir bila konfigurasi pos global belum 100%',
    (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      await tester.tap(find.text('Pemasukan').last);
      await pumpSheet(tester);

      expect(
          find.byKey(const Key('income_wallet_auto_message')), findsOneWidget);
      expect(
        find.textContaining(
            'pemasukan akan dibagi otomatis ke dompet masing-masing'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.enterText(find.byType(TextField).last, 'Gaji lintas dompet');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await pumpSheet(tester);

      final feedbackFinder =
          find.byKey(const Key('transaction_sheet_feedback'));
      expect(feedbackFinder, findsOneWidget);
      expect(
        find.text(
          'Pos keuangan belum 100%. Selesaikan dulu di halaman Pos Keuangan.',
        ),
        findsOneWidget,
      );
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'sheet transaksi utama menampilkan drag handle dan opsi bucket expense income',
    (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
      expect(
        find.byKey(const Key('transaction_bucket_section')),
        findsOneWidget,
      );

      await tester.tap(find.text('Pemasukan').last);
      await pumpSheet(tester);
      expect(find.byKey(const Key('income_bucket_selector')), findsOneWidget);

      await tester.tap(find.text('Pengeluaran').last);
      await pumpSheet(tester);
      expect(find.byKey(const Key('expense_bucket_dropdown')), findsNothing);
      expect(find.text('Pos keuangan belum 100%'), findsOneWidget);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'income lintas dompet valid tetap bisa disimpan saat total pos global 100%',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      final wallets = (await tester.runAsync(() async {
        final wallets = await DatabaseHelper().getActiveWallets();
        return wallets
            .where((wallet) => wallet.name == 'Cash' || wallet.name == 'Bank')
            .toList();
      }))!;
      final buckets = [
        FinancialBucket(
          id: 11,
          name: 'Belanja Cash',
          walletId: wallets.singleWhere((wallet) => wallet.name == 'Cash').id,
          allocationPercentage: 60,
          currentBalance: 0,
          createdDate: now,
          updatedDate: now,
        ),
        FinancialBucket(
          id: 22,
          name: 'Belanja Bank',
          walletId: wallets.singleWhere((wallet) => wallet.name == 'Bank').id,
          allocationPercentage: 40,
          currentBalance: 0,
          createdDate: now,
          updatedDate: now,
        ),
      ];
      await tester.runAsync(() async {
        for (final bucket in buckets) {
          await DatabaseHelper().insertFinancialBucket(bucket);
        }
        await DatabaseHelper().setBucketSystemEnabled(true);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            skipInitialLoad: true,
            initialTransactions: const [],
            initialAllTransactions: const [],
            initialWallets: wallets,
            initialBuckets: buckets,
            initialBucketSystemEnabled: true,
            initialHomeBalanceSourceType: 'total',
            initialHomeBalanceVisibilityHidden: false,
            persistHomeHeroPreferences: false,
          ),
        ),
      );
      await pumpSheet(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      await tester.tap(find.text('Pemasukan').last);
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.enterText(find.byType(TextField).last, 'Gaji valid');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await pumpSheet(tester);
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Simpan Transaksi'),
      );
      // Drain the complete FFI save and home reload before teardown can close DB.
      await tester.runAsync(() async {
        await (saveButton.onPressed! as Future<void> Function())();
      });
      await pumpSheet(tester);

      expect(find.byKey(const Key('transaction_sheet_feedback')), findsNothing);
      expect(find.text('Gaji valid'), findsOneWidget);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'bottom nav memakai ikon dan teks yang lebih besar untuk keterbacaan',
    (tester) async {
      await pumpHome(tester);

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
      await pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '125000');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await pumpSheet(tester);

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
      await pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '125000');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await pumpSheet(tester);
      await tester.tap(find.text('Simpan Transaksi'));
      await pumpSheet(tester);

      expect(
          find.byKey(const Key('transaction_sheet_feedback')), findsOneWidget);
      expect(find.text('Keterangan wajib diisi.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));

      expect(find.byKey(const Key('transaction_sheet_feedback')), findsNothing);
      expect(find.text('Keterangan wajib diisi.'), findsNothing);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'mode pos nonaktif menyembunyikan tuntutan alokasi bucket pada sheet transaksi',
    (tester) async {
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
            ],
            initialBuckets: [
              FinancialBucket(
                id: 11,
                name: 'Belanja Cash',
                walletId: 1,
                allocationPercentage: 100,
                currentBalance: 0,
                createdDate: now,
                updatedDate: now,
              ),
            ],
            initialBucketSystemEnabled: false,
            initialHomeBalanceSourceType: 'total',
            initialHomeBalanceVisibilityHidden: false,
            persistHomeHeroPreferences: false,
          ),
        ),
      );
      await pumpSheet(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      expect(find.byKey(const Key('bucket_mode_off_message')), findsOneWidget);
      expect(find.byKey(const Key('income_bucket_selector')), findsNothing);
      expect(find.byKey(const Key('expense_bucket_dropdown')), findsNothing);
    },
    timeout: shortTimeout,
  );

  testWidgets(
    'tanpa dompet aktif sheet transaksi tidak menyintesis Cash dan langsung memberi feedback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(
            skipInitialLoad: true,
            initialTransactions: [],
            initialAllTransactions: [],
            initialWallets: [],
            initialBuckets: [],
            initialBucketSystemEnabled: false,
            initialHomeBalanceSourceType: 'total',
            initialHomeBalanceVisibilityHidden: false,
            persistHomeHeroPreferences: false,
          ),
        ),
      );
      await pumpSheet(tester);

      await tester.tap(find.byType(FloatingActionButton).first);
      await pumpSheet(tester);

      expect(
        find.text(
            'Aktifkan minimal satu dompet dulu sebelum membuat transaksi.'),
        findsOneWidget,
      );
      expect(find.text('Tambah Transaksi 💰'), findsNothing);
    },
    timeout: shortTimeout,
  );
}
