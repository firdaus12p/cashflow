import 'package:cashflow/main.dart';
import 'package:cashflow/features/notifications/models/notification_payload.dart';
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
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: MainScreen(rescheduleReminders: () async {})));
    await settleIo(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final category in ['Transfer Internal', 'Hutang', 'Piutang']) {
    testWidgets('$category detail cannot edit or delete ledger entries', (tester) async {
      final tx = Transaction(id: 1, type: 'income', amount: 100,
          category: category, description: 'Protected entry', date: DateTime.now());
      await tester.pumpWidget(MaterialApp(home: MainScreen(
        skipInitialLoad: true, initialTransactions: [tx], initialAllTransactions: [tx],
        initialHomeBalanceSourceType: 'total', persistHomeHeroPreferences: false,
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Protected entry'));
      await tester.tap(find.text('Protected entry'));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('transaction_detail_delete_btn'))).onPressed, isNull);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('transaction_detail_edit_btn'))).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final wishlist in [false, true]) {
    testWidgets('${wishlist ? 'wishlist' : 'goal'} validates input and rejects submit reentry', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(Key(wishlist ? 'bottom_nav_wishlist_belanja' : 'bottom_nav_target_tabungan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(wishlist ? '+ Tambah Item' : '+ Goal Baru'));
      await tester.pumpAndSettle();
      final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      final button = find.widgetWithText(ElevatedButton, wishlist ? 'Tambah ke Wishlist' : 'Buat Target');
      await tester.enterText(fields.first, '   ');
      await tester.enterText(fields.last, '100');
      tester.widget<ElevatedButton>(button).onPressed!();
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(fields.first, '  Approved item  ');
      await tester.enterText(fields.last, '0');
      tester.widget<ElevatedButton>(button).onPressed!();
      await tester.pump();
      expect(await tester.runAsync(() async => wishlist ? (await db.getWishlistItems()).length : (await db.getSavingGoals()).length), 0);
      await tester.enterText(fields.last, '100');
      final submit = tester.widget<ElevatedButton>(button).onPressed! as Future<void> Function();
      await tester.runAsync(() => Future.wait([submit(), submit()]));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        if (wishlist) {
          final items = await db.getWishlistItems();
          expect(items, hasLength(1));
          expect(items.single.name, 'Approved item');
          expect(items.single.price, 100);
        } else {
          final goals = await db.getSavingGoals();
          expect(goals, hasLength(1));
          expect(goals.single.name, 'Approved item');
          expect(goals.single.targetAmount, 100);
        }
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completed goal awards badge without any transactions', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() => db.insertSavingGoal(SavingGoal(name: 'Goal only', targetAmount: 100,
        currentAmount: 100, createdDate: now)));
    await pumpHome(tester);
    final badges = (await tester.runAsync(db.getBadges))!;
    expect(badges.where((b) => b.type.startsWith('goal_')), hasLength(1));
    expect((await tester.runAsync(db.getTransactions))!, isEmpty);
  });

  testWidgets('goal topup validates zero then commits once on callback reentry', (tester) async {
    await tester.runAsync(() => db.insertSavingGoal(SavingGoal(name: 'Topup goal',
        targetAmount: 1000, createdDate: DateTime.now())));
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('bottom_nav_target_tabungan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Uang'));
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    final button = find.widgetWithText(ElevatedButton, 'Tambah Uang');
    await tester.enterText(field, '0');
    tester.widget<ElevatedButton>(button).onPressed!();
    await tester.pump();
    expect((await tester.runAsync(db.getSavingGoals))!.single.currentAmount, 0);
    await tester.enterText(field, '100');
    final submit = tester.widget<ElevatedButton>(button).onPressed! as Future<void> Function();
    await tester.runAsync(() => Future.wait([submit(), submit()]));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(db.getSavingGoals))!.single.currentAmount, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist purchase callback reentry charges only once', (tester) async {
    await tester.runAsync(() async {
      await db.insertTransaction(Transaction(type: 'income', amount: 1000,
          category: 'Gaji', description: 'Funding', wallet: 'Cash', walletId: 1, date: DateTime.now()));
      await db.insertWishlistItem(WishlistItem(name: 'Purchase item', price: 100,
          priority: 'medium', createdDate: DateTime.now()));
    });
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('bottom_nav_wishlist_belanja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TextButton, 'Beli Sekarang');
    final submit = tester.widget<TextButton>(button).onPressed! as Future<void> Function();
    await tester.runAsync(() => Future.wait([submit(), submit()]));
    await tester.pumpAndSettle();
    final transactions = (await tester.runAsync(db.getTransactions))!;
    expect(transactions.where((t) => t.type == 'expense'), hasLength(1));
    expect(calculateBalanceForWallet(transactions), 900);
    expect((await tester.runAsync(db.getWishlistItems))!, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist insufficient balance keeps dialog usable for retry', (tester) async {
    await tester.runAsync(() => db.insertWishlistItem(WishlistItem(name: 'Retry item', price: 100,
        priority: 'medium', createdDate: DateTime.now())));
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('bottom_nav_wishlist_belanja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TextButton, 'Beli Sekarang');
    await tester.runAsync(() => (tester.widget<TextButton>(button).onPressed! as Future<void> Function())());
    await tester.pump();
    expect(find.byKey(const Key('wishlist_buy_feedback')), findsOneWidget);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    await tester.runAsync(() => db.insertTransaction(Transaction(type: 'income', amount: 100,
        category: 'Gaji', description: 'Funding', wallet: 'Cash', walletId: 1, date: DateTime.now())));
    await tester.runAsync(() => (tester.widget<TextButton>(button).onPressed! as Future<void> Function())());
    await tester.pumpAndSettle();
    expect((await tester.runAsync(db.getWishlistItems))!, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist commit followed by refresh failure cannot be submitted again', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('bottom_nav_wishlist_belanja')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Tambah Item'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(fields.first, 'Committed once');
    await tester.enterText(fields.last, '100');
    final raw = (await tester.runAsync(() => db.database))!;
    await tester.runAsync(() => raw.execute('ALTER TABLE badges RENAME TO temporarily_unavailable_badges'));
    final submit = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tambah ke Wishlist')).onPressed! as Future<void> Function();
    await tester.runAsync(submit);
    expect(tester.takeException(), isNotNull);
    await tester.runAsync(submit);
    expect((await tester.runAsync(db.getWishlistItems))!, hasLength(1));
    await tester.runAsync(() => raw.execute('ALTER TABLE temporarily_unavailable_badges RENAME TO badges'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup and resume scheduling failure stays handled', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: MainScreen(
      skipInitialLoad: true, initialHomeBalanceSourceType: 'total',
      rescheduleReminders: () async { calls++; throw StateError('private scheduler failure'); },
    )));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    final state = tester.state(find.byType(MainScreen)) as WidgetsBindingObserver;
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('private scheduler'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final notification in [false, true]) {
    testWidgets('${notification ? 'notification' : 'quick menu'} debt return refreshes bucket balance', (tester) async {
      final now = DateTime.now();
      late FinancialBucket bucket;
      late List<Wallet> wallets;
      late int debtId;
      await tester.runAsync(() async {
        wallets = await db.getActiveWallets();
        final id = await db.insertFinancialBucket(FinancialBucket(name: 'Dana', walletId: wallets.first.id,
          allocationPercentage: 100, createdDate: now, updatedDate: now));
        bucket = (await db.getActiveBuckets()).single;
        await db.saveIncomeWithAllocations(amount: 500000, category: 'Gaji', description: 'Seed',
          date: now, walletName: wallets.first.name, subsetBuckets: [bucket]);
        bucket = (await db.getActiveBuckets()).single;
        debtId = await db.insertDebt(Debt(type: 'debt', personName: 'Test', principalAmount: 200000,
          remainingAmount: 200000, borrowedDate: now, recordingMode: 'note', createdDate: now, updatedDate: now));
        await db.setAppPreference('homeBalanceSourceType', 'bucket');
        await db.setAppPreference('homeBalanceSourceId', '$id');
      });
      await tester.pumpWidget(MaterialApp(home: MainScreen(
        skipInitialLoad: true, initialWallets: wallets, initialBuckets: [bucket],
        initialHomeBalanceSourceType: 'bucket', initialHomeBalanceSourceId: bucket.id,
        initialNotificationPayload: notification ? const NotificationPayload(target: NotificationRouteTarget.debts) : null,
        rescheduleReminders: () async { throw StateError('scheduling failed after debt return'); },
      )));
      await settleIo(tester);
      if (!notification) {
        await tester.ensureVisible(find.byKey(const Key('quick_menu_hutang_piutang')));
        await tester.tap(find.byKey(const Key('quick_menu_hutang_piutang')));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() => db.recordDebtPayment(debtId: debtId, amount: 100000,
          paymentDate: now, recordingMode: 'balance', affectedBucket: bucket));
      Navigator.of(tester.element(find.byType(HutangPiutangPage))).pop();
      await settleIo(tester);
      expect(tester.widget<Text>(find.byKey(const Key('home_balance_value'))).data, 'Rp 400.000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
