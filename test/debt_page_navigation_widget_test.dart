// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

final _now = DateTime(2026);

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
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HutangPiutangPage(
          initialDebts: [_makeDebt()],
          initialWallets: _fakeWallets,
          initialBuckets: _fakeBuckets,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('tap item debt membuka HutangDetailPage', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Budi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_detail_page')), findsOneWidget);
  });
}
