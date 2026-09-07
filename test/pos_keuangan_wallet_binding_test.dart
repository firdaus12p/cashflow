// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  testWidgets('mode toggle rejects reentry and recovers after failure',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: PosKeuanganPage(
      initialBuckets: const [],
      initialWallets: const [],
      initialBucketSystemEnabled: true,
      setBucketSystemEnabled: (_) {
        calls++;
        return pending.future;
      },
    )));
    final toggle = find.byKey(const Key('bucket_system_toggle_btn'));
    final change = tester.widget<Switch>(toggle).onChanged!;
    change(false);
    change(false);
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
    pending.completeError(Exception('Simulated failure'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(find.text('Mode pos gagal diubah. Coba lagi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<Wallet> wallets,
    List<FinancialBucket> buckets = const [],
    bool? bucketSystemEnabled,
    Future<Map<int, BucketReconciliationPreview>> Function()?
        previewBucketReconciliations,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PosKeuanganPage(
          initialBuckets: buckets,
          initialWallets: wallets,
          initialBucketSystemEnabled: bucketSystemEnabled,
          previewBucketReconciliations: previewBucketReconciliations,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> pumpSheetFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('menampilkan bucket list dan FAB', (tester) async {
    await pumpPage(
      tester,
      wallets: const [],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          allocationPercentage: 60,
          currentBalance: 500000,
          createdDate: now,
          updatedDate: now,
        ),
        FinancialBucket(
          id: 2,
          name: 'Harian',
          allocationPercentage: 40,
          currentBalance: 300000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
      bucketSystemEnabled: false,
      previewBucketReconciliations: () async => {
        1: (
          walletBalance: 300000,
          bucketBalanceTotal: 0,
          delta: 300000,
          canApply: true,
          balanceChanges: const {1: 300000},
          resultingBalances: const {1: 300000},
        ),
      },
    );

    expect(find.byKey(const Key('bucket_list')), findsOneWidget);
    expect(find.byKey(const Key('pos_fab')), findsOneWidget);
    expect(find.text('Tabungan'), findsOneWidget);
  });

  testWidgets('menampilkan tombol edit bucket', (tester) async {
    await pumpPage(
      tester,
      wallets: const [],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          allocationPercentage: 60,
          currentBalance: 500000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
      bucketSystemEnabled: false,
      previewBucketReconciliations: () async => {
        1: (
          walletBalance: 300000,
          bucketBalanceTotal: 0,
          delta: 300000,
          canApply: true,
          balanceChanges: const {1: 300000},
          resultingBalances: const {1: 300000},
        ),
      },
    );

    expect(find.byKey(const Key('bucket_edit_btn')), findsOneWidget);
  });

  testWidgets('menampilkan status mode pos dan CTA aktivasi saat mode nonaktif',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          walletId: 1,
          allocationPercentage: 100,
          currentBalance: 0,
          createdDate: now,
          updatedDate: now,
        ),
      ],
      bucketSystemEnabled: false,
      previewBucketReconciliations: () async => {
        1: (
          walletBalance: 300000,
          bucketBalanceTotal: 0,
          delta: 300000,
          canApply: true,
          balanceChanges: const {1: 300000},
          resultingBalances: const {1: 300000},
        ),
      },
    );

    expect(find.text('Mode Pos'), findsOneWidget);
    expect(find.byKey(const Key('bucket_system_toggle_btn')), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('bucket_system_toggle_btn')))
          .value,
      isFalse,
    );
    expect(find.text('Aktifkan Pos'), findsNothing);
  });

  testWidgets(
      'header pos keuangan di layar sempit tidak overflow dan tetap wrap',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PosKeuanganPage(
          initialWallets: [
            Wallet(
              id: 1,
              name: 'Cash',
              createdDate: now,
              updatedDate: now,
            ),
          ],
          initialBucketSystemEnabled: false,
          initialBuckets: const [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('bucket_header_controls')), findsOneWidget);
    expect(find.byKey(const Key('bucket_toggle_control')), findsOneWidget);
    expect(find.byKey(const Key('pos_fab')), findsOneWidget);

    final toggleRect =
        tester.getRect(find.byKey(const Key('bucket_toggle_control')));
    final addButtonRect = tester.getRect(find.byKey(const Key('pos_fab')));

    expect(toggleRect.left, greaterThanOrEqualTo(0));
    expect(addButtonRect.left, greaterThanOrEqualTo(0));
    expect(toggleRect.right, lessThanOrEqualTo(360));
    expect(addButtonRect.right, lessThanOrEqualTo(360));
    expect(addButtonRect.top, greaterThanOrEqualTo(toggleRect.top));
  });

  testWidgets('aktivasi pos membuka preview rekonsiliasi per dompet',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          walletId: 1,
          allocationPercentage: 100,
          currentBalance: 0,
          createdDate: now,
          updatedDate: now,
        ),
      ],
      bucketSystemEnabled: false,
      previewBucketReconciliations: () async => {
        1: (
          walletBalance: 300000,
          bucketBalanceTotal: 0,
          delta: 300000,
          canApply: true,
          balanceChanges: const {1: 300000},
          resultingBalances: const {1: 300000},
        ),
      },
    );

    await tester.tap(find.byKey(const Key('bucket_system_toggle_btn')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('bucket_system_activate_dialog')), findsOneWidget);
    expect(find.byKey(const Key('bucket_reconciliation_list')), findsOneWidget);
    expect(find.textContaining('Tabungan'), findsWidgets);
    expect(find.text('Tabungan: Rp 0 -> Rp 300.000 (+Rp 300.000)'),
        findsOneWidget);
    expect(find.textContaining('Rp 300.000'), findsWidgets);
  });

  testWidgets('aktivasi pos ditahan saat total persentase belum 100%',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          walletId: 1,
          allocationPercentage: 30,
          currentBalance: 0,
          createdDate: now,
          updatedDate: now,
        ),
      ],
      bucketSystemEnabled: false,
      previewBucketReconciliations: () async => {
        1: (
          walletBalance: 300000,
          bucketBalanceTotal: 0,
          delta: 300000,
          canApply: true,
          balanceChanges: const {1: 300000},
          resultingBalances: const {1: 300000},
        ),
      },
    );

    await tester.tap(find.byKey(const Key('bucket_system_toggle_btn')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('bucket_system_activate_dialog')), findsNothing);
    expect(
      find.text(
          'Pos keuangan belum 100%. Selesaikan dulu di halaman Pos Keuangan.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan tombol hapus bucket', (tester) async {
    await pumpPage(
      tester,
      wallets: const [],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          allocationPercentage: 60,
          currentBalance: 500000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    expect(find.byKey(const Key('bucket_delete_btn')), findsOneWidget);
    expect(find.byTooltip('Hapus Pos'), findsOneWidget);
  });

  testWidgets('hapus bucket membuka dialog konfirmasi', (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          walletId: 1,
          allocationPercentage: 100,
          currentBalance: 500000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('bucket_delete_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bucket_delete_dialog')), findsOneWidget);
    expect(find.byKey(const Key('bucket_delete_confirm_btn')), findsOneWidget);
    expect(find.text('Hapus Pos?'), findsOneWidget);
  });

  testWidgets('dialog hapus menjelaskan saldo harus dipindahkan dulu',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          walletId: 1,
          allocationPercentage: 100,
          currentBalance: 500000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('bucket_delete_btn')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('saldonya sudah 0'),
      findsOneWidget,
    );
  });

  testWidgets('sheet tambah pos menampilkan dropdown dompet aktif',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('pos_fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('bucket_wallet_dropdown')), findsOneWidget);
  });

  testWidgets('simpan pos tanpa dompet aktif tetap tertahan di sheet',
      (tester) async {
    await pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    await tester.enterText(
      find.byKey(const Key('bucket_name_field')),
      'Belanja',
    );
    await tester.enterText(
      find.byKey(const Key('bucket_pct_field')),
      '40',
    );
    await tester.ensureVisible(find.byKey(const Key('bucket_save_btn')));
    await pumpSheetFrames(tester);
    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('bucket_name_field')), findsOneWidget);
    expect(find.byKey(const Key('page_pos_keuangan')), findsOneWidget);
  });

  testWidgets('sheet tambah pos keuangan menampilkan drag handle',
      (tester) async {
    await pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await pumpSheetFrames(tester);

    expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
  });

  testWidgets(
      'sheet tambah pos menampilkan feedback lokal di bawah drag handle',
      (tester) async {
    await pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('bucket_name_field')),
      'Belanja',
    );
    await tester.enterText(
      find.byKey(const Key('bucket_pct_field')),
      '40',
    );
    await tester.ensureVisible(find.byKey(const Key('bucket_save_btn')));
    await pumpSheetFrames(tester);
    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await pumpSheetFrames(tester);

    expect(find.byKey(const Key('bucket_sheet_feedback')), findsOneWidget);
    expect(
      find.text('Buat dompet aktif dulu sebelum membuat pos.'),
      findsOneWidget,
    );
  });

  testWidgets('drag handle tambah pos bisa ditarik pelan untuk menutup',
      (tester) async {
    await pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await pumpSheetFrames(tester);

    await tester.timedDrag(
      find.byKey(const Key('sheet_drag_handle')),
      const Offset(0, 260),
      const Duration(milliseconds: 700),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bucket_name_field')), findsNothing);
  });

  testWidgets('kartu pos menampilkan saldo sebagai elemen terpisah dan tegas',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Sedekah',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 110000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    expect(find.byKey(const Key('bucket_balance_text')), findsOneWidget);

    final balanceText = tester.widget<Text>(
      find.byKey(const Key('bucket_balance_text')),
    );
    final rootSpan = balanceText.textSpan!;
    final flatText = rootSpan.toPlainText();

    expect(flatText, 'Rp 110.000');
    expect(balanceText.maxLines, 1);
  });

  testWidgets(
      'kartu pos di layar sempit menjaga dompet, persen, dan saldo tetap terbaca',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: MaterialApp(
          home: PosKeuanganPage(
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
                id: 1,
                name: 'Tabungan',
                walletId: 1,
                allocationPercentage: 15,
                currentBalance: 12345678,
                createdDate: now,
                updatedDate: now,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('bucket_wallet_text')), findsOneWidget);
    expect(find.byKey(const Key('bucket_percentage_text')), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('15.0%'), findsOneWidget);

    final balanceRender = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('bucket_balance_text')),
    );
    expect(balanceRender.didExceedMaxLines, isFalse);
  });

  testWidgets(
      'sheet transfer pos menulis nominal dengan format rupiah yang konsisten',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Sedekah',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 110000,
          createdDate: now,
          updatedDate: now,
        ),
        FinancialBucket(
          id: 2,
          name: 'Belanja',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 50000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('bucket_transfer_btn')).first);
    await pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('transfer_amount_field')),
      '125000',
    );
    await tester.pump();

    expect(find.text('125.000'), findsOneWidget);
  });

  testWidgets('sheet transfer pos menampilkan drag handle dan feedback lokal',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Sedekah',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 110000,
          createdDate: now,
          updatedDate: now,
        ),
        FinancialBucket(
          id: 2,
          name: 'Belanja',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 50000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('bucket_transfer_btn')).first);
    await pumpSheetFrames(tester);

    expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer_confirm_btn')));
    await pumpSheetFrames(tester);

    expect(find.byKey(const Key('transfer_sheet_feedback')), findsOneWidget);
    expect(
      find.text('Nominal transfer harus lebih besar dari 0.'),
      findsOneWidget,
    );
  });

  testWidgets('drag handle transfer pos bisa ditarik pelan untuk menutup',
      (tester) async {
    await pumpPage(
      tester,
      wallets: [
        Wallet(
          id: 1,
          name: 'Cash',
          createdDate: now,
          updatedDate: now,
        ),
      ],
      buckets: [
        FinancialBucket(
          id: 1,
          name: 'Sedekah',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 110000,
          createdDate: now,
          updatedDate: now,
        ),
        FinancialBucket(
          id: 2,
          name: 'Belanja',
          walletId: 1,
          allocationPercentage: 50,
          currentBalance: 50000,
          createdDate: now,
          updatedDate: now,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('bucket_transfer_btn')).first);
    await pumpSheetFrames(tester);

    await tester.timedDrag(
      find.byKey(const Key('sheet_drag_handle')),
      const Offset(0, 260),
      const Duration(milliseconds: 700),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_amount_field')), findsNothing);
  });
}
