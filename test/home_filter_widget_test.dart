// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

void main() {
  final now = DateTime(2026, 8, 10, 10);
  final transactions = [
    Transaction(
      id: 1,
      type: 'income',
      amount: 500000,
      category: 'Gaji',
      description: 'Gaji Agustus',
      date: now,
      wallet: 'Cash',
    ),
    Transaction(
      id: 2,
      type: 'expense',
      amount: 80000,
      category: 'Belanja',
      description: 'Belanja Agustus',
      date: now,
      wallet: 'Cash',
    ),
  ];

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialTransactions: transactions,
          initialAllTransactions: transactions,
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          persistHomeHeroPreferences: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpInteractionFrames(WidgetTester tester) async {
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('home filter selection can switch from bulanan to tahunan',
      (tester) async {
    await pumpApp(tester);

    final monthlyLabel = tester.widget<Text>(find.text('Bulanan').first);
    expect(monthlyLabel.style?.color, Colors.white);

    await tester.tap(find.text('Tahunan').first);
    await pumpInteractionFrames(tester);

    final yearlyLabel = tester.widget<Text>(find.text('Tahunan').first);
    expect(yearlyLabel.style?.color, Colors.white);
  });
}
