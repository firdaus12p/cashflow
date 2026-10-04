// Home screen behaviour for transactions whose bucket was removed later.
import 'package:cashflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  final db = DatabaseHelper();
  late FinancialBucket archived;
  late FinancialBucket active;

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

  // "Jajan" is removed after "Bakso" was bought from it.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
        final now = DateTime.now();
        final cash =
            (await db.getActiveWallets()).firstWhere((w) => w.name == 'Cash');
        Future<FinancialBucket> add(String name, double pct) async {
          final id = await db.insertFinancialBucket(FinancialBucket(
              name: name,
              walletId: cash.id,
              allocationPercentage: pct,
              createdDate: now,
              updatedDate: now));
          return (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
        }

        archived = await add('Jajan', 50);
        active = await add('Tabungan', 50);
        await db.setBucketSystemEnabled(true);
        await db.saveIncomeWithAllocations(
            amount: 200000,
            category: 'Gaji',
            description: 'Gaji',
            date: now,
            walletName: cash.name,
            walletId: cash.id,
            subsetBuckets: [archived, active]);
        await db.saveExpenseWithSource(
            amount: 40000,
            category: 'Makanan',
            description: 'Bakso',
            date: now,
            walletName: cash.name,
            walletId: cash.id,
            sourceBucket: (await db.getFinancialBuckets())
                .firstWhere((b) => b.id == archived.id));
        await db.executeBucketTransfer(
            fromBucketId: archived.id!,
            toBucketId: active.id!,
            amount: 60000,
            transferDate: now);
        await db.removeFinancialBucketFromActive(archived.id!);
        final current = (await db.getFinancialBuckets())
            .firstWhere((b) => b.id == active.id);
        await db.updateFinancialBucket(FinancialBucket(
            id: current.id,
            name: current.name,
            walletId: current.walletId,
            allocationPercentage: 100,
            currentBalance: current.currentBalance,
            createdDate: current.createdDate,
            updatedDate: now));
      });

  Future<void> openBakso(WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(home: MainScreen(rescheduleReminders: () async {})));
    await settleIo(tester);
    await tester.ensureVisible(find.text('Bakso').first);
    await tester.tap(find.text('Bakso').first);
    await tester.pumpAndSettle();
  }

  Future<double> activeBalance(WidgetTester tester) async =>
      (await tester.runAsync(() async => (await db.getFinancialBuckets())
              .firstWhere((b) => b.id == active.id)
              .currentBalance))!;

  String? snackText(WidgetTester tester) {
    final texts = tester
        .widgetList<Text>(
            find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))
        .map((t) => t.data)
        .whereType<String>();
    return texts.isEmpty ? null : texts.first;
  }

  // Real DB work finishes at an uneven pace, so poll instead of assuming a
  // fixed delay.
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

  testWidgets('hapus: meminta pos pengganti lalu uang kembali ke pos itu',
      (tester) async {
    await seed(tester);
    await openBakso(tester);
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

    expect(find.byKey(const Key('bucket_replacement_dialog')), findsOneWidget);
    expect(find.textContaining('Jajan'), findsWidgets);
    expect(await activeBalance(tester), 160000);

    tester
        .widget<TextButton>(
            find.byKey(const Key('bucket_replacement_confirm_btn')))
        .onPressed!();
    await settleIo(tester);

    expect(find.byKey(const Key('bucket_replacement_dialog')), findsNothing);
    expect(await waitForSnack(tester), 'Transaksi berhasil dihapus! 🗑️');
    expect(await activeBalance(tester), 200000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('hapus: batal di dialog pengganti tidak mengubah apa pun',
      (tester) async {
    await seed(tester);
    await openBakso(tester);
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
    tester
        .widget<TextButton>(
            find.byKey(const Key('bucket_replacement_cancel_btn')))
        .onPressed!();
    await settleIo(tester);

    expect(find.byKey(const Key('bucket_replacement_dialog')), findsNothing);
    expect(await activeBalance(tester), 160000);
    final stillThere = await tester.runAsync(() async =>
        (await db.getTransactions()).any((t) => t.description == 'Bakso'));
    expect(stillThere, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('edit keterangan saja: pos lama dan saldo tidak berubah',
      (tester) async {
    await seed(tester);
    await openBakso(tester);
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
    await tester.enterText(fields.last, 'Bakso malam');
    final save = find.widgetWithText(ElevatedButton, 'Update Transaksi');
    await tester.ensureVisible(save);
    final onPressed = tester.widget<ElevatedButton>(save).onPressed!
        as Future<void> Function();
    await tester.runAsync(onPressed);
    await settleIo(tester);

    expect(await waitForSnack(tester), 'Transaksi berhasil diperbarui!');
    expect(await activeBalance(tester), 160000);
    final result = await tester.runAsync(() async {
      final tx = (await db.getTransactions())
          .firstWhere((t) => t.description == 'Bakso malam');
      return (await db.getTransactionBucketAllocations(tx.id!)).single;
    });
    expect(result!.bucketId, archived.id);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
