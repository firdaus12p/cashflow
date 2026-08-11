// ignore_for_file: depend_on_referenced_packages

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
}) =>
    Debt(
      id: id,
      type: 'debt',
      personName: 'Budi',
      principalAmount: principal,
      remainingAmount: remaining,
      borrowedDate: _now,
      recordingMode: mode,
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
