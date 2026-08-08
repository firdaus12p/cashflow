// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:pinkycash_app/main.dart';

// Pure Dart Debt objects — tidak ada DB call di dalam testWidgets
// (sqflite_ffi pakai real isolate, tidak bisa di-await di fake-async zone)
final _now = DateTime(2026);
final _pastDate = DateTime(2025, 1, 1);

Debt _makeDebt({
  int id = 1,
  String type = 'debt',
  String person = 'Budi',
  double principal = 500000,
  double remaining = 300000,
  String mode = 'note',
  String status = 'active',
  DateTime? due,
}) =>
    Debt(
      id: id,
      type: type,
      personName: person,
      principalAmount: principal,
      remainingAmount: remaining,
      borrowedDate: _now,
      dueDate: due,
      recordingMode: mode,
      status: status,
      createdDate: _now,
      updatedDate: _now,
    );

final _fakeDebts = [
  _makeDebt(id: 1, type: 'debt', person: 'Budi', remaining: 300000),
  _makeDebt(
      id: 2,
      type: 'receivable',
      person: 'Sari',
      remaining: 200000,
      due: _pastDate),
  _makeDebt(id: 3, person: 'Anton', remaining: 0, status: 'settled'),
];

final _fakeWallets = [
  Wallet(
    id: 1,
    name: 'Cash',
    iconKey: 'cash',
    createdDate: _now,
    updatedDate: _now,
  ),
  Wallet(
    id: 2,
    name: 'Bank',
    iconKey: 'bank',
    createdDate: _now,
    updatedDate: _now,
  ),
];

final _fakeBuckets = [
  FinancialBucket(
    id: 1,
    name: 'Dana Darurat',
    iconKey: 'emergency',
    allocationPercentage: 100,
    currentBalance: 500000,
    createdDate: _now,
    updatedDate: _now,
  ),
];

void main() {
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

  // ---------------------------------------------------------------------------
  // HutangPiutangPage — tampilan daftar
  // gap: initialDebts parameter dan widget keys belum ada — Task 6.2
  // ---------------------------------------------------------------------------

  group('HutangPiutangPage — tampilan daftar', () {
    testWidgets('menampilkan debt_list ketika ada data', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: _fakeDebts)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_list')), findsOneWidget);
    });

    testWidgets('menampilkan nama orang di setiap item', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: _fakeDebts)));
      await tester.pumpAndSettle();

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Sari'), findsOneWidget);
    });

    testWidgets('menampilkan empty state bila tidak ada hutang/piutang',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: HutangPiutangPage(initialDebts: [])));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada hutang/piutang'), findsOneWidget);
      expect(find.byKey(const Key('debt_list')), findsNothing);
    });

    testWidgets('FAB untuk tambah record tersedia', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: _fakeDebts)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_fab')), findsOneWidget);
    });

    testWidgets('menampilkan label tipe — Hutang untuk debt', (tester) async {
      final debts = [_makeDebt(type: 'debt', person: 'Citra')];
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: debts)));
      await tester.pumpAndSettle();

      expect(find.text('Hutang'), findsWidgets);
    });

    testWidgets('menampilkan label tipe — Piutang untuk receivable',
        (tester) async {
      final debts = [_makeDebt(type: 'receivable', person: 'Dani')];
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: debts)));
      await tester.pumpAndSettle();

      expect(find.text('Piutang'), findsWidgets);
    });

    testWidgets('menampilkan label Terlambat untuk debt yang overdue',
        (tester) async {
      final debts = [
        _makeDebt(remaining: 100000, due: _pastDate, status: 'active')
      ];
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: debts)));
      await tester.pumpAndSettle();

      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('menampilkan label Lunas untuk debt settled', (tester) async {
      final debts = [_makeDebt(remaining: 0, status: 'settled')];
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: debts)));
      await tester.pumpAndSettle();

      expect(find.text('Lunas'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // HutangPiutangPage — form tambah
  // ---------------------------------------------------------------------------

  group('HutangPiutangPage — form tambah', () {
    testWidgets('form muncul setelah tap FAB', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HutangPiutangPage(
        initialDebts: _fakeDebts,
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_form_page')), findsOneWidget);
      expect(find.byKey(const Key('debt_person_field')), findsOneWidget);
      expect(find.byKey(const Key('debt_amount_field')), findsOneWidget);
      expect(find.byKey(const Key('debt_mode_selector')), findsOneWidget);
    });

    testWidgets('mode selector menampilkan helper text Masuk ke saldo',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HutangPiutangPage(
        initialDebts: const [],
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Masuk ke saldo'), findsWidgets);
      expect(find.text('Catatan saja'), findsWidgets);
    });

    testWidgets('form tambah menampilkan selector dompet dan pos',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HutangPiutangPage(
        initialDebts: const [],
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_wallet_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('debt_bucket_dropdown')), findsOneWidget);
    });

    testWidgets('form tambah menampilkan field tanggal dan catatan',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HutangPiutangPage(
        initialDebts: const [],
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_borrowed_date_btn')), findsOneWidget);
      expect(find.byKey(const Key('debt_due_date_btn')), findsOneWidget);
      expect(find.byKey(const Key('debt_note_field')), findsOneWidget);
    });

    testWidgets('submit kosong menampilkan validasi nama pihak',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HutangPiutangPage(
        initialDebts: const [],
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('debt_save_btn')));
      await tester.tap(find.byKey(const Key('debt_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Nama pihak tidak boleh kosong'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // HutangDetailPage — navigasi dan konten
  // gap: HutangDetailPage belum ada — Task 6.2
  // ---------------------------------------------------------------------------

  group('HutangDetailPage — konten', () {
    testWidgets('tap item debt membuka HutangDetailPage', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: _fakeDebts)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Budi'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_detail_page')), findsOneWidget);
    });

    testWidgets('detail menampilkan progress pembayaran', (tester) async {
      final debt = _makeDebt(
          id: 10, principal: 500000, remaining: 200000, person: 'Test');
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_progress_bar')), findsOneWidget);
    });

    testWidgets('detail menampilkan tombol Catat Pembayaran', (tester) async {
      final debt = _makeDebt(id: 10, status: 'active');
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_pay_btn')), findsOneWidget);
    });

    testWidgets('detail tidak menampilkan pay button bila sudah settled',
        (tester) async {
      final debt = _makeDebt(id: 10, remaining: 0, status: 'settled');
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_pay_btn')), findsNothing);
    });

    testWidgets('detail menampilkan tombol edit debt', (tester) async {
      final debt = _makeDebt(id: 10, status: 'active');
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_edit_btn')), findsOneWidget);
    });

    testWidgets('tap edit membuka form penuh dengan data awal', (tester) async {
      final debt = Debt(
        id: 10,
        type: 'debt',
        personName: 'Budi',
        principalAmount: 500000,
        remainingAmount: 300000,
        borrowedDate: _now,
        dueDate: DateTime(2026, 2, 1),
        recordingMode: 'note',
        walletId: 1,
        bucketId: 1,
        note: 'Catatan lama',
        createdDate: _now,
        updatedDate: _now,
      );
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(
          debt: debt,
          initialPayments: const [],
          initialWallets: _fakeWallets,
          initialBuckets: _fakeBuckets,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_edit_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_form_page')), findsOneWidget);
      expect(find.text('Edit Hutang / Piutang'), findsOneWidget);
      expect(find.text('Budi'), findsWidgets);
      expect(find.text('Catatan lama'), findsOneWidget);
    });

    testWidgets('detail menampilkan metadata dompet pos dan catatan',
        (tester) async {
      final debt = Debt(
        id: 10,
        type: 'receivable',
        personName: 'Sari',
        principalAmount: 200000,
        remainingAmount: 100000,
        borrowedDate: _now,
        dueDate: DateTime(2026, 3, 1),
        recordingMode: 'balance',
        walletId: 2,
        bucketId: 1,
        note: 'Tagih minggu depan',
        createdDate: _now,
        updatedDate: _now,
      );
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(
          debt: debt,
          initialPayments: const [],
          initialWallets: _fakeWallets,
          initialBuckets: _fakeBuckets,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal pinjam'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Pos Keuangan'), findsOneWidget);
      expect(find.text('Dana Darurat'), findsOneWidget);
      expect(find.text('Catatan'), findsOneWidget);
      expect(find.text('Tagih minggu depan'), findsOneWidget);
    });

    testWidgets('payment sheet menampilkan ringkasan mode dan selector bucket',
        (tester) async {
      final debt = _makeDebt(id: 10, status: 'active', mode: 'balance');
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_pay_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_mode_indicator')), findsOneWidget);
      expect(find.byKey(const Key('payment_bucket_dropdown')), findsOneWidget);
    });
  });
}
