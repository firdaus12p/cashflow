// Home screen warning shown before a correction drives a balance below zero.
import 'package:cashflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final db = DatabaseHelper();

  setUpAll(initializeSharedTestDatabase);
  setUp(() async {
    await resetSharedTestDatabase();
    mockTestFontAssets();
  });
  tearDownAll(disposeSharedTestDatabase);

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
  }

  // 1.000.000 income, then 800.000 spent: removing the income leaves -800.000.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
        final now = DateTime.now();
        final cash =
            (await db.getActiveWallets()).firstWhere((w) => w.name == 'Cash');
        Future<void> add(String type, double amount, String desc) =>
            db.insertTransaction(Transaction(
              type: type,
              amount: amount,
              category: type == 'income' ? 'Gaji' : 'Makanan',
              description: desc,
              date: now,
              wallet: cash.name,
              walletId: cash.id,
            ));
        await add('income', 1000000, 'Gaji typo');
        await add('expense', 800000, 'Belanja bulanan');
      });

  Future<void> openDetail(WidgetTester tester, String description) async {
    await tester.pumpWidget(
        MaterialApp(home: MainScreen(rescheduleReminders: () async {})));
    await settleIo(tester);
    await tester.ensureVisible(find.text(description).first);
    await tester.tap(find.text(description).first);
    await tester.pumpAndSettle();
  }

  String? snackText(WidgetTester tester) {
    final texts = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(SnackBar), matching: find.byType(Text)))
        .map((t) => t.data)
        .whereType<String>();
    return texts.isEmpty ? null : texts.first;
  }

  Future<String?> waitForSnack(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      final text = snackText(tester);
      if (text != null) return text;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    return null;
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.ensureVisible(
        find.byKey(const Key('transaction_detail_delete_btn')));
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(
            find.byKey(const Key('transaction_detail_delete_btn')))
        .onPressed!();
    await settleIo(tester);
    tester
        .widget<TextButton>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Hapus')))
        .onPressed!();
    await settleIo(tester);
  }

  Future<int> salaryCount(WidgetTester tester) async =>
      (await tester.runAsync(() async => (await db.getTransactions())
              .where((t) => t.description == 'Gaji typo')
              .length))!;

  testWidgets('hapus pemasukan: peringatan saldo minus, lalu terhapus',
      (tester) async {
    await seed(tester);
    await openDetail(tester, 'Gaji typo');
    await confirmDelete(tester);

    expect(find.byKey(const Key('negative_balance_dialog')), findsOneWidget);
    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('Rp -800.000'), findsOneWidget);
    expect(await salaryCount(tester), 1);

    tester
        .widget<TextButton>(
            find.byKey(const Key('negative_balance_confirm_btn')))
        .onPressed!();
    expect(await waitForSnack(tester), 'Transaksi berhasil dihapus! 🗑️');
    expect(await salaryCount(tester), 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('hapus pemasukan: batal pada peringatan tidak mengubah apa pun',
      (tester) async {
    await seed(tester);
    await openDetail(tester, 'Gaji typo');
    await confirmDelete(tester);
    tester
        .widget<TextButton>(find.byKey(const Key('negative_balance_cancel_btn')))
        .onPressed!();
    await settleIo(tester);

    expect(find.byKey(const Key('negative_balance_dialog')), findsNothing);
    expect(await salaryCount(tester), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('edit nominal pemasukan: peringatan saldo minus, lalu tersimpan',
      (tester) async {
    await seed(tester);
    await openDetail(tester, 'Gaji typo');
    await tester
        .ensureVisible(find.byKey(const Key('transaction_detail_edit_btn')));
    await tester.pumpAndSettle();
    tester
        .widget<ElevatedButton>(
            find.byKey(const Key('transaction_detail_edit_btn')))
        .onPressed!();
    await settleIo(tester);

    final fields = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(fields.first, '100000');
    final save = find.widgetWithText(ElevatedButton, 'Update Transaksi');
    await tester.ensureVisible(save);
    final onPressed = tester.widget<ElevatedButton>(save).onPressed!
        as Future<void> Function();
    // Real DB work only advances inside runAsync, so poll rather than await.
    onPressed();
    await settleIo(tester);

    expect(find.byKey(const Key('negative_balance_dialog')), findsOneWidget);
    expect(find.textContaining('Rp -700.000'), findsOneWidget);

    tester
        .widget<TextButton>(
            find.byKey(const Key('negative_balance_confirm_btn')))
        .onPressed!();
    expect(await waitForSnack(tester), 'Transaksi berhasil diperbarui!');
    final amount = await tester.runAsync(() async => (await db.getTransactions())
        .firstWhere((t) => t.description == 'Gaji typo')
        .amount);
    expect(amount, 100000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
