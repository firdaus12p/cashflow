// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

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
    walletId: 1,
    iconKey: 'emergency',
    allocationPercentage: 100,
    currentBalance: 500000,
    createdDate: _now,
    updatedDate: _now,
  ),
];

Future<void> _pumpDebtPage(
  WidgetTester tester, {
  List<Debt> debts = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HutangPiutangPage(
        initialDebts: debts,
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
        initialBucketSystemEnabled: true,
      ),
    ),
  );
  await _pumpUi(tester);
}

Future<void> _pumpDebtDetail(
  WidgetTester tester, {
  required Debt debt,
  List<DebtPayment> payments = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HutangDetailPage(
        debt: debt,
        initialPayments: payments,
        initialWallets: _fakeWallets,
        initialBuckets: _fakeBuckets,
        initialBucketSystemEnabled: true,
      ),
    ),
  );
  await _pumpUi(tester);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _openDebtForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('debt_fab')));
  await _pumpUi(tester);
}

Future<void> _openPaymentSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('debt_pay_btn')));
  await _pumpUi(tester);
}

void main() {
  // ---------------------------------------------------------------------------
  // HutangPiutangPage — tampilan daftar
  // gap: initialDebts parameter dan widget keys belum ada — Task 6.2
  // ---------------------------------------------------------------------------

  group('HutangPiutangPage — tampilan daftar', () {
    testWidgets('menampilkan debt_list ketika ada data', (tester) async {
      await _pumpDebtPage(tester, debts: _fakeDebts);

      expect(find.byKey(const Key('debt_list')), findsOneWidget);
    });

    testWidgets('menampilkan nama orang di setiap item', (tester) async {
      await _pumpDebtPage(tester, debts: _fakeDebts);

      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Sari'), findsOneWidget);
    });

    testWidgets('menampilkan empty state bila tidak ada hutang/piutang',
        (tester) async {
      await _pumpDebtPage(tester);

      expect(find.text('Belum ada hutang/piutang'), findsOneWidget);
      expect(find.byKey(const Key('debt_list')), findsNothing);
    });

    testWidgets('FAB untuk tambah record tersedia', (tester) async {
      await _pumpDebtPage(tester, debts: _fakeDebts);

      expect(find.byKey(const Key('debt_fab')), findsOneWidget);
    });

    testWidgets('menampilkan label tipe — Hutang untuk debt', (tester) async {
      final debts = [_makeDebt(type: 'debt', person: 'Citra')];
      await _pumpDebtPage(tester, debts: debts);

      expect(find.text('Hutang'), findsWidgets);
    });

    testWidgets('menampilkan label tipe — Piutang untuk receivable',
        (tester) async {
      final debts = [_makeDebt(type: 'receivable', person: 'Dani')];
      await _pumpDebtPage(tester, debts: debts);

      expect(find.text('Piutang'), findsWidgets);
    });

    testWidgets('menampilkan label Terlambat untuk debt yang overdue',
        (tester) async {
      final debts = [
        _makeDebt(remaining: 100000, due: _pastDate, status: 'active')
      ];
      await _pumpDebtPage(tester, debts: debts);

      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('menampilkan label Lunas untuk debt settled', (tester) async {
      final debts = [_makeDebt(remaining: 0, status: 'settled')];
      await _pumpDebtPage(tester, debts: debts);

      expect(find.text('Lunas'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // HutangPiutangPage — form tambah
  // ---------------------------------------------------------------------------

  group('HutangPiutangPage — form tambah', () {
    testWidgets('form muncul setelah tap FAB', (tester) async {
      await _pumpDebtPage(tester, debts: _fakeDebts);
      await _openDebtForm(tester);

      expect(find.byKey(const Key('debt_form_page')), findsNothing);
      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
      expect(find.byKey(const Key('debt_form_surface')), findsNothing);
      expect(find.byKey(const Key('debt_person_field')), findsOneWidget);
      expect(find.byKey(const Key('debt_amount_field')), findsOneWidget);
      expect(find.byKey(const Key('debt_mode_selector')), findsOneWidget);
      expect(find.text('Siapa?'), findsOneWidget);
    });

    testWidgets('sheet debt tidak memakai kotak form tambahan', (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);

      expect(find.byKey(const Key('debt_form_surface')), findsNothing);
    });

    testWidgets('mode selector menampilkan helper text Masuk ke saldo',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);

      expect(find.text('Masuk ke saldo'), findsWidgets);
      expect(find.text('Catatan saja'), findsWidgets);
    });

    testWidgets('form tambah menampilkan selector dompet dan pos',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);

      expect(find.byKey(const Key('debt_wallet_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('debt_bucket_dropdown')), findsOneWidget);
    });

    testWidgets('form tambah mode pos nonaktif menampilkan pesan dompet-only',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => DebtFormSheet(
                        initialWallets: _fakeWallets,
                        initialBuckets: _fakeBuckets,
                        initialBucketSystemEnabled: false,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Masuk ke saldo').first,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Masuk ke saldo').first, warnIfMissed: false);
      await _pumpUi(tester);

      expect(find.byKey(const Key('debt_bucket_mode_off_message')),
          findsOneWidget);
      expect(
        find.text(
          'Sistem pos sedang nonaktif. Catatan ini akan mengikuti dompet saja.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('debt_bucket_dropdown')), findsNothing);
    });

    testWidgets('form tambah menampilkan field tanggal dan catatan',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);

      expect(find.byKey(const Key('debt_borrowed_date_btn')), findsOneWidget);
      expect(find.byKey(const Key('debt_due_date_btn')), findsOneWidget);
      expect(find.byKey(const Key('debt_note_field')), findsOneWidget);
    });

    testWidgets(
        'form tambah menampilkan label yang lebih jelas seperti form transaksi',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);

      expect(find.text('Nama Orang'), findsOneWidget);
      expect(find.text('Nominal'), findsWidgets);
      expect(find.text('Tanggal Pinjam'), findsOneWidget);
      expect(find.text('Jatuh Tempo'), findsOneWidget);
      expect(find.text('Catatan Tambahan'), findsOneWidget);
    });

    testWidgets('submit kosong menampilkan validasi nama pihak',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);
      await tester.pumpAndSettle(); // selesaikan animasi bottom sheet

      await tester.scrollUntilVisible(
        find.byKey(const Key('debt_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const Key('debt_save_btn')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle(); // beri waktu setState untuk rebuild

      expect(find.byKey(const Key('debt_sheet_feedback')), findsOneWidget);
      expect(find.text('Nama pihak tidak boleh kosong'), findsOneWidget);
    });

    testWidgets('feedback form tambah hilang otomatis setelah sebentar',
        (tester) async {
      await _pumpDebtPage(tester);
      await _openDebtForm(tester);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('debt_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const Key('debt_save_btn')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Nama pihak tidak boleh kosong'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));

      expect(find.byKey(const Key('debt_sheet_feedback')), findsNothing);
      expect(find.text('Nama pihak tidak boleh kosong'), findsNothing);
    });

    testWidgets('drag handle form tambah bisa ditarik pelan untuk menutup',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_direct_debt_sheet_btn'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => DebtFormSheet(
                        initialWallets: _fakeWallets,
                        initialBuckets: _fakeBuckets,
                        initialBucketSystemEnabled: true,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_direct_debt_sheet_btn')));
      await tester.pumpAndSettle();

      await tester.timedDrag(
        find.byKey(const Key('sheet_drag_handle')),
        const Offset(0, 260),
        const Duration(milliseconds: 700),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_person_field')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // HutangDetailPage — navigasi dan konten
  // gap: HutangDetailPage belum ada — Task 6.2
  // ---------------------------------------------------------------------------

  group('HutangDetailPage — konten', () {
    testWidgets('detail menampilkan progress pembayaran', (tester) async {
      final debt = _makeDebt(
          id: 10, principal: 500000, remaining: 200000, person: 'Test');
      await _pumpDebtDetail(tester, debt: debt);

      expect(find.byKey(const Key('debt_progress_bar')), findsOneWidget);
    });

    testWidgets('detail menampilkan tombol Catat Pembayaran', (tester) async {
      final debt = _makeDebt(id: 10, status: 'active');
      await _pumpDebtDetail(tester, debt: debt);

      expect(find.byKey(const Key('debt_pay_btn')), findsOneWidget);
    });

    testWidgets('detail tidak menampilkan pay button bila sudah settled',
        (tester) async {
      final debt = _makeDebt(id: 10, remaining: 0, status: 'settled');
      await _pumpDebtDetail(tester, debt: debt);

      expect(find.byKey(const Key('debt_pay_btn')), findsNothing);
    });

    testWidgets('detail menampilkan tombol edit debt', (tester) async {
      final debt = _makeDebt(id: 10, status: 'active');
      await _pumpDebtDetail(tester, debt: debt);

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
      await _pumpDebtDetail(tester, debt: debt);

      await tester.tap(find.byKey(const Key('debt_edit_btn')));
      await _pumpUi(tester);

      expect(find.byKey(const Key('debt_form_page')), findsNothing);
      expect(find.text('Edit Hutang / Piutang'), findsOneWidget);
      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
      expect(find.text('Budi'), findsWidgets);
      expect(find.text('Catatan lama'), findsWidgets);
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
      await _pumpDebtDetail(tester, debt: debt);

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
      await _pumpDebtDetail(tester, debt: debt);

      await _openPaymentSheet(tester);

      expect(find.byKey(const Key('payment_mode_indicator')), findsOneWidget);
      expect(find.byKey(const Key('payment_bucket_dropdown')), findsOneWidget);
    });

    testWidgets(
        'payment sheet tidak menawarkan bucket yang sudah dihapus untuk pembayaran baru',
        (tester) async {
      final debt = Debt(
        id: 10,
        type: 'debt',
        personName: 'Budi',
        principalAmount: 500000,
        remainingAmount: 300000,
        borrowedDate: _now,
        recordingMode: 'balance',
        walletId: 1,
        bucketId: 99,
        createdDate: _now,
        updatedDate: _now,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HutangDetailPage(
            debt: debt,
            initialPayments: const [],
            initialWallets: _fakeWallets,
            initialBuckets: [
              FinancialBucket(
                id: 99,
                name: 'Pos Lama',
                walletId: 1,
                allocationPercentage: 100,
                currentBalance: 0,
                isArchived: true,
                createdDate: _now,
                updatedDate: _now,
              ),
              ..._fakeBuckets,
            ],
            initialBucketSystemEnabled: true,
          ),
        ),
      );
      await _pumpUi(tester);

      await _openPaymentSheet(tester);

      expect(find.byKey(const Key('payment_bucket_dropdown')), findsOneWidget);
      expect(find.text('Dana Darurat'), findsOneWidget);
    });

    testWidgets(
        'payment sheet tetap bisa simpan saat total bucket aktif 100% walau histori memuat bucket arsip',
        (tester) async {
      final calls = <String>[];
      final debt = Debt(
        id: 10,
        type: 'debt',
        personName: 'Budi',
        principalAmount: 500000,
        remainingAmount: 300000,
        borrowedDate: _now,
        recordingMode: 'balance',
        walletId: 1,
        bucketId: 99,
        createdDate: _now,
        updatedDate: _now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HutangDetailPage(
            debt: debt,
            initialPayments: const [],
            initialWallets: _fakeWallets,
            initialBuckets: [
              FinancialBucket(
                id: 99,
                name: 'Pos Lama',
                walletId: 1,
                allocationPercentage: 100,
                currentBalance: 0,
                isArchived: true,
                createdDate: _now,
                updatedDate: _now,
              ),
              ..._fakeBuckets,
            ],
            initialBucketSystemEnabled: true,
            recordDebtPayment: ({
              required int debtId,
              required double amount,
              required DateTime paymentDate,
              required String recordingMode,
              int? walletId,
              int? bucketId,
              FinancialBucket? affectedBucket,
            }) async {
              calls.add('record');
            },
            loadDebtById: (debtId) async {
              calls.add('loadDebt');
              return debt;
            },
            loadPaymentsByDebt: (debtId) async {
              calls.add('loadPayments');
              return const <DebtPayment>[];
            },
            refreshReminderSchedule: () async {},
          ),
        ),
      );
      await _pumpUi(tester);

      await _openPaymentSheet(tester);
      await tester.enterText(
        find.byKey(const Key('payment_amount_field')),
        '100000',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _pumpUi(tester);
      tester
          .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
          .onPressed!();
      await tester.pumpAndSettle();

      expect(calls, ['record', 'loadDebt', 'loadPayments']);
      expect(
        find.text(
          'Pos keuangan belum 100%. Selesaikan dulu di halaman Pos Keuangan.',
        ),
        findsNothing,
      );
    });

    testWidgets(
        'payment sheet mode pos nonaktif tidak menahan save karena bucket',
        (tester) async {
      final calls = <Map<String, Object?>>[];
      final debt = Debt(
        id: 10,
        type: 'debt',
        personName: 'Budi',
        principalAmount: 500000,
        remainingAmount: 300000,
        borrowedDate: _now,
        recordingMode: 'balance',
        walletId: 1,
        bucketId: 1,
        createdDate: _now,
        updatedDate: _now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HutangDetailPage(
            debt: debt,
            initialPayments: const [],
            initialWallets: _fakeWallets,
            initialBuckets: const [],
            initialBucketSystemEnabled: false,
            recordDebtPayment: ({
              required int debtId,
              required double amount,
              required DateTime paymentDate,
              required String recordingMode,
              int? walletId,
              int? bucketId,
              FinancialBucket? affectedBucket,
            }) async {
              calls.add({
                'event': 'record',
                'bucketId': bucketId,
                'affectedBucket': affectedBucket,
              });
            },
            loadDebtById: (debtId) async {
              calls.add({'event': 'loadDebt'});
              return debt;
            },
            loadPaymentsByDebt: (debtId) async {
              calls.add({'event': 'loadPayments'});
              return const <DebtPayment>[];
            },
            refreshReminderSchedule: () async {},
          ),
        ),
      );
      await _pumpUi(tester);

      await _openPaymentSheet(tester);
      await tester.enterText(
        find.byKey(const Key('payment_amount_field')),
        '100000',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _pumpUi(tester);
      tester
          .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
          .onPressed!();
      await tester.pumpAndSettle();

      expect(calls.map((entry) => entry['event']).toList(), [
        'record',
        'loadDebt',
        'loadPayments',
      ]);
      expect(calls.first['bucketId'], isNull);
      expect(calls.first['affectedBucket'], isNull);
      expect(
        find.text('Buat pos keuangan aktif dulu untuk pembayaran ini.'),
        findsNothing,
      );
    });

    testWidgets('payment sheet menampilkan drag handle yang konsisten',
        (tester) async {
      final debt = _makeDebt(id: 10, status: 'active', mode: 'note');
      await _pumpDebtDetail(tester, debt: debt);

      await _openPaymentSheet(tester);

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
    });

    testWidgets('payment sheet menampilkan feedback lokal di bawah drag handle',
        (tester) async {
      final debt = _makeDebt(id: 10, status: 'active', mode: 'note');
      await _pumpDebtDetail(tester, debt: debt);

      await _openPaymentSheet(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const Key('payment_save_btn')),
        warnIfMissed: false,
      );
      await _pumpUi(tester);

      expect(find.byKey(const Key('payment_sheet_feedback')), findsOneWidget);
      expect(find.text('Nominal cicilan harus lebih besar dari 0.'),
          findsOneWidget);
    });

    testWidgets('feedback payment sheet hilang otomatis setelah sebentar',
        (tester) async {
      final debt = _makeDebt(id: 10, status: 'active', mode: 'note');
      await _pumpDebtDetail(tester, debt: debt);

      await _openPaymentSheet(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment_save_btn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const Key('payment_save_btn')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Nominal cicilan harus lebih besar dari 0.'),
          findsOneWidget);

      await tester.pump(const Duration(seconds: 4));

      expect(find.byKey(const Key('payment_sheet_feedback')), findsNothing);
      expect(
          find.text('Nominal cicilan harus lebih besar dari 0.'), findsNothing);
    });

    testWidgets('drag handle payment sheet bisa ditarik pelan untuk menutup',
        (tester) async {
      final debt = _makeDebt(id: 10, status: 'active', mode: 'note');
      await _pumpDebtDetail(tester, debt: debt);

      await _openPaymentSheet(tester);
      await tester.pumpAndSettle();

      await tester.timedDrag(
        find.byKey(const Key('sheet_drag_handle')),
        const Offset(0, 260),
        const Duration(milliseconds: 700),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    });
  });
}
