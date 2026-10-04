// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

final _now = DateTime(2026);

Debt _makeDebt({
  int id = 1,
  double principal = 500000,
  double remaining = 300000,
  String mode = 'note',
  String status = 'active',
  int? walletId,
  int? bucketId,
}) =>
    Debt(
      id: id,
      type: 'debt',
      personName: 'Budi',
      principalAmount: principal,
      remainingAmount: remaining,
      borrowedDate: _now,
      recordingMode: mode,
      walletId: walletId,
      bucketId: bucketId,
      status: status,
      createdDate: _now,
      updatedDate: _now,
    );

final _wallets = [
  Wallet(
    id: 1,
    name: 'Cash',
    iconKey: 'cash',
    createdDate: _now,
    updatedDate: _now,
  ),
];

final _buckets = [
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

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets(
      'late payment commit refreshes dismissed sheet parent once and blocks reopening',
      (tester) async {
    final pending = Completer<void>();
    final refreshPending = Completer<void>();
    var debt = _makeDebt(remaining: 300000);
    final payments = <DebtPayment>[];
    var inserts = 0;
    var debtLoads = 0;
    var paymentLoads = 0;
    await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(
      debt: debt,
      initialPayments: const [],
      initialWallets: _wallets,
      initialBuckets: const [],
      recordDebtPayment: (
          {required int debtId,
          required double amount,
          required DateTime paymentDate,
          required String recordingMode,
          int? walletId,
          int? bucketId,
          FinancialBucket? affectedBucket}) async {
        inserts++;
        await pending.future;
        debt = _makeDebt(remaining: 200000);
        payments.add(DebtPayment(
            id: 1,
            debtId: debtId,
            amount: amount,
            paymentDate: paymentDate,
            recordingMode: recordingMode,
            createdDate: paymentDate));
      },
      loadDebtById: (_) async {
        debtLoads++;
        await refreshPending.future;
        return debt;
      },
      loadPaymentsByDebt: (_) async {
        paymentLoads++;
        return payments;
      },
      refreshReminderSchedule: () async {},
    )));
    final pay = find.byKey(const Key('debt_pay_btn'));
    final open = tester.widget<FloatingActionButton>(pay).onPressed!;
    open();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('payment_amount_field')), '100000');
    final save = tester
        .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
        .onPressed!;
    save();
    save();
    Navigator.of(tester.element(find.byKey(const Key('payment_amount_field'))))
        .pop();
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingActionButton>(pay).onPressed, isNull);
    open(); // Even a callback captured before the disabled rebuild is guarded.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    expect(inserts, 1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(debtLoads, 1);
    expect(paymentLoads, 0);
    expect(tester.widget<FloatingActionButton>(pay).onPressed, isNull);
    open();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    refreshPending.complete();
    await tester.pumpAndSettle();
    expect(debtLoads, 1);
    expect(paymentLoads, 1);
    expect(find.text('Sisa: Rp 200.000'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);

    await tester.tap(pay);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('payment_amount_field')), '250000');
    tester
        .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
        .onPressed!();
    save(); // A callback from the dismissed sheet cannot insert again.
    await tester.pump();
    expect(find.text('Nominal cicilan melebihi sisa yang harus dibayar.'),
        findsOneWidget);
    expect(inserts, 1);
    expect(debtLoads, 1);
    expect(paymentLoads, 1);
    Navigator.of(tester.element(find.byKey(const Key('payment_amount_field'))))
        .pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment sheet menerima nominal setara setelah pembulatan rupiah',
      (tester) async {
    final debt = _makeDebt(principal: 2537214, remaining: 2537213.6);
    final calls = <Map<String, Object?>>[];

    await tester.pumpWidget(MaterialApp(
      home: HutangDetailPage(
        debt: debt,
        initialPayments: const [],
        initialWallets: _wallets,
        initialBuckets: const [],
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
            'debtId': debtId,
            'amount': amount,
            'mode': recordingMode,
          });
        },
        loadDebtById: (_) async => debt,
        loadPaymentsByDebt: (_) async => const <DebtPayment>[],
        refreshReminderSchedule: () async {},
      ),
    ));

    await tester.tap(find.byKey(const Key('debt_pay_btn')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('payment_amount_field')),
      '2537214',
    );
    tester
        .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(
      find.text('Nominal cicilan melebihi sisa yang harus dibayar.'),
      findsNothing,
    );
    expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final bucketEnabled in [false, true]) {
    testWidgets(
        'note-origin payment can affect balance, buckets $bucketEnabled',
        (tester) async {
      final debt = _makeDebt();
      final bank =
          Wallet(id: 2, name: 'Bank', createdDate: _now, updatedDate: _now);
      final buckets = [
        for (final wallet in [..._wallets, bank])
          FinancialBucket(
            id: wallet.id,
            name: 'Pos ${wallet.name}',
            walletId: wallet.id,
            allocationPercentage: 50,
            currentBalance: 500000,
            createdDate: _now,
            updatedDate: _now,
          ),
      ];
      final pending = Completer<void>();
      final calls = <Map<String, Object?>>[];
      await tester.pumpWidget(MaterialApp(
          home: HutangDetailPage(
        debt: debt,
        initialPayments: const [],
        initialWallets: [..._wallets, bank],
        initialBuckets: buckets,
        initialBucketSystemEnabled: bucketEnabled,
        recordDebtPayment: (
            {required int debtId,
            required double amount,
            required DateTime paymentDate,
            required String recordingMode,
            int? walletId,
            int? bucketId,
            FinancialBucket? affectedBucket}) async {
          calls.add({
            'mode': recordingMode,
            'wallet': walletId,
            'bucket': bucketId,
            'affected': affectedBucket?.id
          });
          await pending.future;
        },
        loadDebtById: (_) async => debt,
        loadPaymentsByDebt: (_) async => [],
        refreshReminderSchedule: () async {},
      )));
      await tester.tap(find.byKey(const Key('debt_pay_btn')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                  find.byKey(const Key('payment_mode_dropdown')))
              .initialValue,
          'note');
      await tester.tap(find.byKey(const Key('payment_mode_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk ke saldo').last);
      await tester.pumpAndSettle();

      if (bucketEnabled) {
        expect(find.text('Dompet: Cash'), findsOneWidget);
        await tester.tap(find.byKey(const Key('payment_bucket_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pos Bank').last);
      } else {
        expect(
            find.byKey(const Key('payment_wallet_dropdown')), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('payment_amount_field')), '10000');
        tester
            .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
            .onPressed!();
        await tester.pump();
        expect(calls, isEmpty);
        expect(find.text('Pilih dompet untuk mode Masuk ke saldo.'),
            findsOneWidget);
        await tester
            .ensureVisible(find.byKey(const Key('payment_wallet_dropdown')));
        await tester.tap(find.byKey(const Key('payment_wallet_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bank').last);
      }
      await tester.pumpAndSettle();
      expect(find.text('Dompet: Bank'), findsOneWidget);
      expect(find.text('Dompet: Cash'), findsNothing);
      await tester.enterText(
          find.byKey(const Key('payment_amount_field')), '10000');
      final save = tester
          .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
          .onPressed!;
      save();
      save(); // Re-enter before a rebuild, not just after disabling the button.
      await tester.pump();
      expect(calls, [
        {
          'mode': 'balance',
          'wallet': 2,
          'bucket': bucketEnabled ? 2 : null,
          'affected': bucketEnabled ? 2 : null
        },
      ]);
      expect(
          tester
              .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
              .onPressed,
          isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment_amount_field')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'balance-origin payment can be note-only without financial binding',
      (tester) async {
    final debt = _makeDebt(mode: 'balance', walletId: 1, bucketId: 1);
    final calls = <Map<String, Object?>>[];
    await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(
      debt: debt,
      initialPayments: const [],
      initialWallets: _wallets,
      initialBuckets: const [],
      initialBucketSystemEnabled: true,
      recordDebtPayment: (
          {required int debtId,
          required double amount,
          required DateTime paymentDate,
          required String recordingMode,
          int? walletId,
          int? bucketId,
          FinancialBucket? affectedBucket}) async {
        calls.add({
          'mode': recordingMode,
          'wallet': walletId,
          'bucket': bucketId,
          'affected': affectedBucket
        });
      },
      loadDebtById: (_) async => debt,
      loadPaymentsByDebt: (_) async => [],
      refreshReminderSchedule: () async {},
    )));
    await tester.tap(find.byKey(const Key('debt_pay_btn')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const Key('payment_mode_dropdown')))
            .initialValue,
        'balance');
    await tester.tap(find.byKey(const Key('payment_mode_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catatan saja').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment_bucket_dropdown')), findsNothing);
    expect(find.byKey(const Key('payment_wallet_dropdown')), findsNothing);
    await tester.enterText(
        find.byKey(const Key('payment_amount_field')), '10000');
    tester
        .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(calls, [
      {'mode': 'note', 'wallet': null, 'bucket': null, 'affected': null}
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'payment dismissed with focused keyboard tolerates late save failure',
      (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(
      debt: _makeDebt(),
      initialPayments: const [],
      initialWallets: _wallets,
      initialBuckets: const [],
      recordDebtPayment: (
              {required int debtId,
              required double amount,
              required DateTime paymentDate,
              required String recordingMode,
              int? walletId,
              int? bucketId,
              FinancialBucket? affectedBucket}) =>
          pending.future,
    )));
    await tester.tap(find.byKey(const Key('debt_pay_btn')));
    await tester.pumpAndSettle();
    final amount = find.byKey(const Key('payment_amount_field'));
    await tester.enterText(amount, '10000');
    expect(tester.testTextInput.isVisible, isTrue);
    tester
        .widget<ElevatedButton>(find.byKey(const Key('payment_save_btn')))
        .onPressed!();
    Navigator.of(tester.element(amount)).pop();
    await tester.pumpAndSettle();
    pending.completeError(Exception('Simulated failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'simpan pembayaran merefresh detail setelah sheet tertutup tanpa exception',
      (tester) async {
    var currentDebt = _makeDebt(id: 10, remaining: 300000);
    var currentPayments = <DebtPayment>[];
    final callOrder = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HutangDetailPage(
          debt: currentDebt,
          initialPayments: const [],
          initialWallets: _wallets,
          initialBuckets: _buckets,
          recordDebtPayment: ({
            required int debtId,
            required double amount,
            required DateTime paymentDate,
            required String recordingMode,
            int? walletId,
            int? bucketId,
            FinancialBucket? affectedBucket,
          }) async {
            callOrder.add('record');
            currentDebt = Debt(
              id: currentDebt.id,
              type: currentDebt.type,
              personName: currentDebt.personName,
              principalAmount: currentDebt.principalAmount,
              remainingAmount: currentDebt.remainingAmount - amount,
              borrowedDate: currentDebt.borrowedDate,
              dueDate: currentDebt.dueDate,
              recordingMode: currentDebt.recordingMode,
              status: currentDebt.remainingAmount - amount <= 0
                  ? 'settled'
                  : 'active',
              walletId: currentDebt.walletId,
              bucketId: currentDebt.bucketId,
              note: currentDebt.note,
              createdDate: currentDebt.createdDate,
              updatedDate: paymentDate,
            );
            currentPayments = [
              DebtPayment(
                id: 1,
                debtId: debtId,
                amount: amount,
                paymentDate: paymentDate,
                recordingMode: recordingMode,
                walletId: walletId,
                bucketId: bucketId,
                createdDate: paymentDate,
              ),
            ];
          },
          loadDebtById: (debtId) async {
            callOrder.add('loadDebt');
            return currentDebt;
          },
          loadPaymentsByDebt: (debtId) async {
            callOrder.add('loadPayments');
            return currentPayments;
          },
          refreshReminderSchedule: () async {},
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byKey(const Key('debt_pay_btn')));
    await _pumpUi(tester);

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
    await tester.tap(
      find.byKey(const Key('payment_save_btn')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(callOrder, ['record', 'loadDebt', 'loadPayments']);
    expect(find.byKey(const Key('payment_amount_field')), findsNothing);
    expect(find.text('Sisa: Rp 200.000'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
