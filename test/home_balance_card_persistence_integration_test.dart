// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

import 'test_support/db_test_harness.dart';

const _sourceTypePreferenceKey = 'homeBalanceSourceType';
const _sourceIdPreferenceKey = 'homeBalanceSourceId';
const _visibilityHiddenPreferenceKey = 'homeBalanceVisibilityHidden';

void main() {
  setUpAll(() async {
    await initializeSharedTestDatabase();
  });

  setUp(() async {
    await resetSharedTestDatabase();
  });

  tearDownAll(() async {
    await disposeSharedTestDatabase();
  });

  Future<void> _savePreference(String key, String value) async {
    await DatabaseHelper().setAppPreference(key, value);
  }

  Future<void> _pumpInjectedHome(
    WidgetTester tester, {
    required List<Wallet> wallets,
    required List<Transaction> transactions,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialTransactions: transactions,
          initialAllTransactions: transactions,
          initialWallets: wallets,
          persistHomeHeroPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('preferensi hero tersimpan dan dipulihkan saat app dibuka ulang',
      (tester) async {
    final wallet = Wallet(
      id: 1,
      name: 'Cash',
      createdDate: DateTime(2026, 8, 9),
      updatedDate: DateTime(2026, 8, 9),
    );

    final now = DateTime(2026, 8, 9);
    final transactions = [
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Cash income',
        date: now,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Belanja',
        description: 'Cash expense',
        date: now,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'income',
        amount: 300000,
        category: 'Gaji',
        description: 'Bank income',
        date: now,
        wallet: 'Bank',
      ),
    ];

    await _savePreference(_sourceTypePreferenceKey, 'wallet');
    await _savePreference(_sourceIdPreferenceKey, '1');
    await _savePreference(_visibilityHiddenPreferenceKey, '1');

    await _pumpInjectedHome(
      tester,
      wallets: [wallet],
      transactions: transactions,
    );

    expect(find.text('Saldo Cash'), findsOneWidget);
    expect(find.text('Rp 400.000'), findsNothing);
    expect(find.text('Rp 700.000'), findsNothing);
    expect(find.text('Rp ••••••'), findsWidgets);
  });
}
