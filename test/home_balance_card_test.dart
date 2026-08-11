// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/main.dart';

void main() {
  Future<void> _pumpInjectedHome(
    WidgetTester tester, {
    List<Wallet>? wallets,
    List<FinancialBucket>? buckets,
    List<Transaction>? transactions,
    String? sourceType,
    int? sourceId,
    bool? isHidden,
    bool persistPreferences = false,
    bool injectHomePreferences = true,
  }) async {
    final fixtureTransactions =
        List<Transaction>.from(transactions ?? const []);

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialTransactions: fixtureTransactions,
          initialAllTransactions: fixtureTransactions,
          initialWallets: wallets,
          initialBuckets: buckets,
          initialHomeBalanceSourceType:
              injectHomePreferences ? (sourceType ?? 'total') : null,
          initialHomeBalanceSourceId: injectHomePreferences ? sourceId : null,
          initialHomeBalanceVisibilityHidden:
              injectHomePreferences ? (isHidden ?? false) : null,
          persistHomeHeroPreferences: persistPreferences,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> _pumpHeroInteraction(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('hero fallback ke Total Saldo bila wallet source hilang',
      (tester) async {
    await _pumpInjectedHome(
      tester,
      sourceType: 'wallet',
      sourceId: 999,
    );

    expect(find.text('Total Saldo'), findsOneWidget);
  });

  testWidgets('hero fallback ke Total Saldo bila bucket source hilang',
      (tester) async {
    await _pumpInjectedHome(
      tester,
      sourceType: 'bucket',
      sourceId: 999,
    );

    expect(find.text('Total Saldo'), findsOneWidget);
  });

  testWidgets('hero menampilkan label dompet sesuai source aktif',
      (tester) async {
    final wallet = Wallet(
      id: 1,
      name: 'Cash',
      createdDate: DateTime(2026, 8, 9),
      updatedDate: DateTime(2026, 8, 9),
    );

    await _pumpInjectedHome(
      tester,
      wallets: [wallet],
      sourceType: 'wallet',
      sourceId: 1,
    );

    expect(find.text('Saldo Cash'), findsOneWidget);
  });

  testWidgets('hero menampilkan label pos sesuai source aktif', (tester) async {
    final bucket = FinancialBucket(
      id: 9,
      name: 'Belanja',
      allocationPercentage: 50,
      currentBalance: 125000,
      createdDate: DateTime(2026, 8, 9),
      updatedDate: DateTime(2026, 8, 9),
    );

    await _pumpInjectedHome(
      tester,
      buckets: [bucket],
      sourceType: 'bucket',
      sourceId: 9,
    );

    expect(find.text('Saldo Belanja'), findsOneWidget);
  });

  testWidgets('eye toggle menyembunyikan seluruh angka di hero',
      (tester) async {
    final now = DateTime(2026, 8, 9);
    final transactions = [
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Gaji',
        date: now,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Belanja',
        description: 'Belanja',
        date: now,
        wallet: 'Cash',
      ),
    ];

    await _pumpInjectedHome(tester, transactions: transactions);

    expect(find.text('Rp 400.000'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_balance_visibility_toggle')));
    await _pumpHeroInteraction(tester);

    expect(find.text('Rp 400.000'), findsNothing);
    expect(find.text('Rp 500.000'), findsNothing);
    expect(find.text('Rp 100.000'), findsNothing);
    expect(find.text('Rp ••••••'), findsWidgets);
  });

  testWidgets('source selector mengubah label hero tanpa boot penuh',
      (tester) async {
    final wallet = Wallet(
      id: 1,
      name: 'Cash',
      createdDate: DateTime(2026, 8, 9),
      updatedDate: DateTime(2026, 8, 9),
    );

    await _pumpInjectedHome(tester, wallets: [wallet]);

    await tester.tap(find.byKey(const Key('home_balance_source_button')));
    await _pumpHeroInteraction(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Dompet: Cash').last);
    await _pumpHeroInteraction(tester);

    expect(find.text('Saldo Cash'), findsOneWidget);
  });
}
