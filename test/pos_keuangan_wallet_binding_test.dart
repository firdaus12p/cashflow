// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:cashflow/main.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.overrideDatabasePath(':memory:');
  });

  tearDown(() async {
    await DatabaseHelper.closeDatabase();
  });

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

  testWidgets(
      'mengizinkan simpan pos bertahap selama total belum melebihi 100%',
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
    await _pumpSheetFrames(tester);

    await tester.enterText(
      find.byKey(const Key('bucket_name_field')),
      'Tabungan',
    );
    await tester.enterText(
      find.byKey(const Key('bucket_pct_field')),
      '30',
    );

    await tester.tap(find.byKey(const Key('bucket_save_btn')));
    await _pumpSheetFrames(tester);

    final savedBuckets = await DatabaseHelper().getFinancialBuckets();
    expect(savedBuckets, hasLength(1));
    expect(savedBuckets.single.name, 'Tabungan');
    expect(savedBuckets.single.allocationPercentage, 30);
    expect(
      find.text('Total persentase semua pos tidak boleh lebih dari 100%.'),
      findsNothing,
    );
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
}
