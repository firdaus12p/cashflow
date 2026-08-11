// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  Future<void> _pumpPage(
    WidgetTester tester, {
    required List<Wallet> wallets,
    List<FinancialBucket> buckets = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PosKeuanganPage(
          initialBuckets: buckets,
          initialWallets: wallets,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> _pumpSheetFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('menampilkan bucket list dan FAB', (tester) async {
    await _pumpPage(
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
    );

    expect(find.byKey(const Key('bucket_list')), findsOneWidget);
    expect(find.byKey(const Key('pos_fab')), findsOneWidget);
    expect(find.text('Tabungan'), findsOneWidget);
  });

  testWidgets('menampilkan tombol edit bucket', (tester) async {
    await _pumpPage(
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

    expect(find.byKey(const Key('bucket_edit_btn')), findsOneWidget);
  });

  testWidgets('sheet tambah pos menampilkan dropdown dompet aktif',
      (tester) async {
    await _pumpPage(
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
    await _pumpPage(tester, wallets: const []);

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
    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('bucket_name_field')), findsOneWidget);
    expect(find.byKey(const Key('page_pos_keuangan')), findsOneWidget);
  });

  testWidgets('sheet tambah pos keuangan menampilkan drag handle',
      (tester) async {
    await _pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await _pumpSheetFrames(tester);

    expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
  });

  testWidgets(
      'sheet tambah pos menampilkan feedback lokal di bawah drag handle',
      (tester) async {
    await _pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await _pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('bucket_name_field')),
      'Belanja',
    );
    await tester.enterText(
      find.byKey(const Key('bucket_pct_field')),
      '40',
    );
    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await _pumpSheetFrames(tester);

    expect(find.byKey(const Key('bucket_sheet_feedback')), findsOneWidget);
    expect(
      find.text('Buat dompet aktif dulu sebelum membuat pos.'),
      findsOneWidget,
    );
  });

  testWidgets('drag handle tambah pos bisa ditarik pelan untuk menutup',
      (tester) async {
    await _pumpPage(tester, wallets: const []);

    await tester.tap(find.byKey(const Key('pos_fab')));
    await _pumpSheetFrames(tester);

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
    await _pumpPage(
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
      'sheet transfer pos menulis nominal dengan format rupiah yang konsisten',
      (tester) async {
    await _pumpPage(
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
    await _pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('transfer_amount_field')),
      '125000',
    );
    await tester.pump();

    expect(find.text('125.000'), findsOneWidget);
  });

  testWidgets('sheet transfer pos menampilkan drag handle dan feedback lokal',
      (tester) async {
    await _pumpPage(
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
    await _pumpSheetFrames(tester);

    expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer_confirm_btn')));
    await _pumpSheetFrames(tester);

    expect(find.byKey(const Key('transfer_sheet_feedback')), findsOneWidget);
    expect(
      find.text('Nominal transfer harus lebih besar dari 0.'),
      findsOneWidget,
    );
  });

  testWidgets('drag handle transfer pos bisa ditarik pelan untuk menutup',
      (tester) async {
    await _pumpPage(
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
    await _pumpSheetFrames(tester);

    await tester.timedDrag(
      find.byKey(const Key('sheet_drag_handle')),
      const Offset(0, 260),
      const Duration(milliseconds: 700),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_amount_field')), findsNothing);
  });
}
