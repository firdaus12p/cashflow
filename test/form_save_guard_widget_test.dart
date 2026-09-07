import 'dart:async';

import 'package:cashflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editing in [false, true]) {
    testWidgets('${editing ? 'edit' : 'add'} transaction rejects zero before database access',
        (tester) async {
      final now = DateTime.now();
      final transaction = Transaction(id: 1, type: 'income', amount: 10000,
          category: 'Gaji', description: 'Zero validation', date: now,
          wallet: 'Cash', walletId: 1);
      var inserts = 0;
      await tester.pumpWidget(MaterialApp(home: MainScreen(
        skipInitialLoad: true,
        initialWallets: [Wallet(id: 1, name: 'Cash', createdDate: now, updatedDate: now)],
        initialTransactions: editing ? [transaction] : const [],
        initialAllTransactions: editing ? [transaction] : const [],
        initialBuckets: const [],
        initialBucketSystemEnabled: false,
        initialHomeBalanceSourceType: 'total',
        initialHomeBalanceVisibilityHidden: false,
        persistHomeHeroPreferences: false,
        insertTransaction: (_) async {
          inserts++;
          throw ArgumentError('Private database values');
        },
      )));
      await tester.pumpAndSettle();
      if (editing) {
        await tester.ensureVisible(find.text('Zero validation'));
        await tester.drag(find.text('Zero validation'), const Offset(-600, 0));
      } else {
        await tester.tap(find.byKey(const Key('bottom_nav_add_transaction')));
      }
      await tester.pumpAndSettle();
      expect(find.text(editing ? 'Edit Transaksi' : 'Tambah Transaksi 💰'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.enterText(find.byType(TextField).last, 'Zero validation');
      final button = find.widgetWithText(ElevatedButton,
          editing ? 'Update Transaksi' : 'Simpan Transaksi');
      tester.widget<ElevatedButton>(button).onPressed!();
      await tester.pump();
      expect(find.text('Jumlah harus lebih besar dari 0 dan valid.'), findsOneWidget);
      expect(inserts, 0);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);

      if (!editing) {
        await tester.enterText(find.byType(TextField).first, '10000');
        tester.widget<ElevatedButton>(button).onPressed!();
        await tester.pump();
        expect(inserts, 1);
        expect(find.text('Nominal transaksi tidak valid. Periksa jumlah yang diisi.'), findsOneWidget);
        expect(find.textContaining('Private database values'), findsNothing);
        expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      }
      Navigator.of(tester.element(button)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final form in ['transaction', 'debt']) {
    testWidgets('$form disables save and ignores reentry before rebuild',
        (tester) async {
      final now = DateTime(2026);
      final wallets = [
        Wallet(id: 1, name: 'Cash', createdDate: now, updatedDate: now)
      ];
      final pending = Completer<int>();
      final transactions = <Transaction>[];
      final debts = <Debt>[];
      if (form == 'transaction') {
        await tester.pumpWidget(MaterialApp(
            home: MainScreen(
          skipInitialLoad: true,
          initialWallets: wallets,
          initialBuckets: const [],
          initialBucketSystemEnabled: false,
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          persistHomeHeroPreferences: false,
          insertTransaction: (transaction) {
            transactions.add(transaction);
            return pending.future;
          },
        )));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bottom_nav_add_transaction')));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Pemasukan')));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, '10000');
        await tester.enterText(find.byType(TextField).last, 'Guard test');
      } else {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => DebtFormSheet(
                initialWallets: wallets,
                initialBuckets: const [],
                initialBucketSystemEnabled: false,
                insertDebt: (debt) {
                  debts.add(debt);
                  return pending.future;
                },
              ),
            ),
            child: const Text('Open'),
          ),
        ))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const Key('debt_person_field')), 'Guard test');
        await tester.enterText(
            find.byKey(const Key('debt_amount_field')), '10000');
      }
      final button = form == 'transaction'
          ? find.widgetWithText(ElevatedButton, 'Simpan Transaksi')
          : find.byKey(const Key('debt_save_btn'));
      final save = tester.widget<ElevatedButton>(button).onPressed!;
      save();
      save();
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      if (form == 'transaction') {
        expect(transactions, hasLength(1));
        expect(transactions.single.description, 'Guard test');
        expect(transactions.single.amount, 10000);
      } else {
        expect(debts, hasLength(1));
        expect(debts.single.personName, 'Guard test');
        expect(debts.single.principalAmount, 10000);
      }
      expect(tester.testTextInput.isVisible, isTrue);
      Navigator.of(tester.element(button)).pop();
      await tester.pumpAndSettle();
      pending.completeError(Exception('Simulated save failure'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
