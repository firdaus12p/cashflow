// ignore_for_file: depend_on_referenced_packages

// Suite regresi lintas-fitur Phase 2–6.
// Setiap test di sini membuktikan integrasi antara minimal dua domain fitur.
// Test per-domain sudah ada di test files masing-masing; file ini hanya
// mencakup skenario yang bisa patah ketika fitur baru bertemu flow lama.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:pinkycash_app/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.overrideDatabasePath(':memory:');
  });

  tearDown(() async {
    await DatabaseHelper.closeDatabase();
  });

  final _now = DateTime(2026);

  // ---------------------------------------------------------------------------
  // Regresi 1: Histori transaksi tetap terbaca setelah dompet diarsipkan
  // Phase 4 (wallet) × Phase 2 (walletNameSnapshot)
  // ---------------------------------------------------------------------------

  group('R1 — histori transaksi terbaca setelah wallet diarsipkan', () {
    test('walletNameSnapshot tidak hilang setelah wallet diarsipkan', () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Regresi',
        createdDate: _now,
        updatedDate: _now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 75000.0,
        'category': 'Makanan',
        'description': 'Makan siang',
        'date': _now.millisecondsSinceEpoch,
        'wallet': 'Dompet Regresi',
        'walletId': walletId,
        'walletNameSnapshot': 'Dompet Regresi',
        'affectsBalance': 1,
      });

      await db.archiveWallet(walletId);

      final rows = await rawDb
          .query('transactions', where: 'walletId = ?', whereArgs: [walletId]);
      expect(rows.first['walletNameSnapshot'], 'Dompet Regresi',
          reason: 'Snapshot harus tetap ada setelah dompet diarsipkan');

      final activeWallets = await db.getActiveWallets();
      expect(activeWallets.any((w) => w.name == 'Dompet Regresi'), isFalse,
          reason: 'Dompet yang diarsipkan tidak muncul di daftar aktif');
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 2: Saldo bucket konsisten setelah operasi berurutan
  // Phase 5 (bucket) × Phase 6 (debt payment)
  // ---------------------------------------------------------------------------

  group('R2 — saldo bucket konsisten setelah income allocation + debt payment',
      () {
    test('total saldo bucket tidak berubah setelah alokasi income', () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tabungan',
        allocationPercentage: 60,
        currentBalance: 0,
        createdDate: _now,
        updatedDate: _now,
      ));
      final b2 = await db.insertFinancialBucket(FinancialBucket(
        name: 'Harian',
        allocationPercentage: 40,
        currentBalance: 0,
        createdDate: _now,
        updatedDate: _now,
      ));

      final bucket1 =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == b1);
      final bucket2 =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == b2);

      const income = 1000000.0;
      await db.saveIncomeWithAllocations(
        amount: income,
        category: 'Gaji',
        description: 'Gaji Juli',
        date: _now,
        walletName: 'Cash',
        subsetBuckets: [bucket1, bucket2],
      );

      final buckets = await db.getFinancialBuckets();
      final totalBalance = buckets.fold(0.0, (s, b) => s + b.currentBalance);
      expect(totalBalance, closeTo(income, 0.01),
          reason:
              'Total saldo bucket harus sama dengan income yang dialokasikan');
    });

    test('debt payment mode=balance + income allocation tetap konsisten',
        () async {
      final db = DatabaseHelper();
      await db.database;

      // Setup: satu bucket dengan saldo awal dari income
      final bucketId = await db.insertFinancialBucket(FinancialBucket(
        name: 'Dana Darurat',
        allocationPercentage: 100,
        currentBalance: 500000,
        createdDate: _now,
        updatedDate: _now,
      ));
      final bucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);

      // Buat hutang dan catat cicilan yang memengaruhi bucket
      final debtId = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Rekan',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: _now,
        recordingMode: 'balance',
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: _now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      // Bucket harus berkurang 100.000 (membayar hutang = uang keluar dari pos)
      final updated =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);
      expect(updated.currentBalance, closeTo(400000, 0.01));

      // Hutang juga harus berkurang
      final updatedDebt = (await db.getDebtById(debtId))!;
      expect(updatedDebt.remainingAmount, closeTo(100000, 0.01));
      expect(updatedDebt.status, 'active');
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 3: Debt complete lifecycle — Phase 6 end-to-end
  // ---------------------------------------------------------------------------

  group('R3 — debt lifecycle end-to-end', () {
    test('beberapa cicilan berurutan menetapkan status settled dengan benar',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final debtId = await db.insertDebt(Debt(
        type: 'receivable',
        personName: 'Pelanggan',
        principalAmount: 300000,
        remainingAmount: 300000,
        borrowedDate: _now,
        recordingMode: 'note',
        createdDate: _now,
        updatedDate: _now,
      ));

      // Cicilan 1 — masih active
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: _now,
          recordingMode: 'note');
      expect((await db.getDebtById(debtId))!.status, 'active');
      expect((await db.getDebtById(debtId))!.remainingAmount,
          closeTo(200000, 0.01));

      // Cicilan 2 — masih active
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: _now,
          recordingMode: 'note');
      expect((await db.getDebtById(debtId))!.status, 'active');

      // Cicilan 3 — lunas
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: _now,
          recordingMode: 'note');
      final settled = (await db.getDebtById(debtId))!;
      expect(settled.status, 'settled');
      expect(settled.remainingAmount, closeTo(0, 0.01));

      final payments = await db.getDebtPaymentsByDebt(debtId);
      expect(payments.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 4: Logic functions Phase 2/5 tidak dipengaruhi domain baru
  // ---------------------------------------------------------------------------

  group('R4 — logic functions lama tetap benar setelah domain baru ditambahkan',
      () {
    test(
        'calculateMonthlyExpenseForInsight mengabaikan transaksi affectsBalance=0',
        () {
      // Transaksi "catatan saja" (affectsBalance=false) tidak seharusnya
      // masuk statistik — pastikan helper lama masih benar
      final now = DateTime(2026, 8, 15);
      final txs = [
        Transaction(
          type: 'expense',
          amount: 100000,
          category: 'Makanan',
          description: 'Reguler',
          date: DateTime(2026, 8, 1),
          wallet: 'Cash',
          affectsBalance: true,
        ),
        Transaction(
          type: 'expense',
          amount: 999999, // catatan saja — tidak boleh dihitung
          category: 'Catatan',
          description: 'Debt note',
          date: DateTime(2026, 8, 2),
          wallet: 'Cash',
          affectsBalance: false,
        ),
      ];

      final result = calculateMonthlyExpenseForInsight(txs, now);
      expect(result, 100000,
          reason:
              'Transaksi catatan saja tidak boleh memengaruhi insight expense');
    });

    test('validateBucketPercentages akurat dengan floating point real-world',
        () {
      final now = DateTime(2026);
      // Skenario nyata: 3 pos dengan pembagian tidak rata
      final buckets = [
        FinancialBucket(
            name: 'A',
            allocationPercentage: 33.34,
            createdDate: now,
            updatedDate: now),
        FinancialBucket(
            name: 'B',
            allocationPercentage: 33.33,
            createdDate: now,
            updatedDate: now),
        FinancialBucket(
            name: 'C',
            allocationPercentage: 33.33,
            createdDate: now,
            updatedDate: now),
      ];
      expect(validateBucketPercentages(buckets), isTrue,
          reason: '33.34 + 33.33 + 33.33 = 100.00 harus valid');
    });

    test('effectiveIcon fallback ke emoji untuk record lama tanpa iconKey', () {
      final goal = SavingGoal(
        name: 'Test',
        targetAmount: 100,
        emoji: '🎯',
        createdDate: DateTime(2026),
      );
      expect(goal.effectiveIcon, '🎯');
      expect(goal.iconKey, isNull);
    });

    test(
        'Debt.isOverdue edge case — dueDate kemarin adalah terlambat, besok tidak',
        () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      final overdueDebt = Debt(
        type: 'debt',
        personName: 'Test',
        principalAmount: 100,
        remainingAmount: 100,
        borrowedDate: yesterday,
        dueDate: yesterday,
        recordingMode: 'note',
        status: 'active',
        createdDate: yesterday,
        updatedDate: yesterday,
      );
      expect(overdueDebt.isOverdue, isTrue,
          reason: 'dueDate kemarin sudah terlambat');

      final futureDebt = Debt(
        type: 'debt',
        personName: 'Test2',
        principalAmount: 100,
        remainingAmount: 100,
        borrowedDate: yesterday,
        dueDate: tomorrow,
        recordingMode: 'note',
        status: 'active',
        createdDate: yesterday,
        updatedDate: yesterday,
      );
      expect(futureDebt.isOverdue, isFalse,
          reason: 'dueDate besok belum terlambat');
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 5: Shell UI — quick menu dan halaman baru tidak crash
  // testWidgets pakai pure Dart objects, zero DB calls
  // ---------------------------------------------------------------------------

  group('R5 — shell UI regression (widget level)', () {
    final _now2 = DateTime(2026);

    testWidgets('DompetPage menampilkan wallet dengan benar', (tester) async {
      final wallets = [
        Wallet(id: 1, name: 'Cash', createdDate: _now2, updatedDate: _now2),
        Wallet(id: 2, name: 'Bank', createdDate: _now2, updatedDate: _now2),
      ];
      await tester
          .pumpWidget(MaterialApp(home: DompetPage(initialWallets: wallets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_list')), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
    });

    testWidgets('PosKeuanganPage menampilkan bucket list dan FAB',
        (tester) async {
      final buckets = [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          allocationPercentage: 60,
          currentBalance: 500000,
          createdDate: _now2,
          updatedDate: _now2,
        ),
        FinancialBucket(
          id: 2,
          name: 'Harian',
          allocationPercentage: 40,
          currentBalance: 300000,
          createdDate: _now2,
          updatedDate: _now2,
        ),
      ];
      await tester.pumpWidget(
          MaterialApp(home: PosKeuanganPage(initialBuckets: buckets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bucket_list')), findsOneWidget);
      expect(find.byKey(const Key('pos_fab')), findsOneWidget);
      expect(find.text('Tabungan'), findsOneWidget);
    });

    testWidgets('PosKeuanganPage menampilkan tombol edit bucket',
        (tester) async {
      final buckets = [
        FinancialBucket(
          id: 1,
          name: 'Tabungan',
          allocationPercentage: 60,
          currentBalance: 500000,
          createdDate: _now2,
          updatedDate: _now2,
        ),
      ];
      await tester.pumpWidget(
          MaterialApp(home: PosKeuanganPage(initialBuckets: buckets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bucket_edit_btn')), findsOneWidget);
    });

    testWidgets(
        'PosKeuanganPage mengizinkan simpan pos bertahap selama total belum melebihi 100%',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PosKeuanganPage(initialBuckets: [])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('bucket_name_field')),
        'Tabungan',
      );
      await tester.enterText(
        find.byKey(const Key('bucket_pct_field')),
        '30',
      );

      await tester.tap(find.byKey(const Key('bucket_save_btn')));
      await tester.pumpAndSettle();

      final savedBuckets = await DatabaseHelper().getFinancialBuckets();
      expect(savedBuckets, hasLength(1));
      expect(savedBuckets.single.name, 'Tabungan');
      expect(savedBuckets.single.allocationPercentage, 30);
      expect(
        find.text('Total persentase semua pos tidak boleh lebih dari 100%.'),
        findsNothing,
      );
    });

    testWidgets('HutangPiutangPage menampilkan list dengan tipe label benar',
        (tester) async {
      final debts = [
        Debt(
          id: 1,
          type: 'debt',
          personName: 'Budi',
          principalAmount: 500000,
          remainingAmount: 300000,
          borrowedDate: _now2,
          recordingMode: 'note',
          status: 'active',
          createdDate: _now2,
          updatedDate: _now2,
        ),
        Debt(
          id: 2,
          type: 'receivable',
          personName: 'Sari',
          principalAmount: 200000,
          remainingAmount: 0,
          borrowedDate: _now2,
          recordingMode: 'balance',
          status: 'settled',
          createdDate: _now2,
          updatedDate: _now2,
        ),
      ];
      await tester.pumpWidget(
          MaterialApp(home: HutangPiutangPage(initialDebts: debts)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_list')), findsOneWidget);
      expect(find.text('Hutang'), findsOneWidget);
      expect(find.text('Piutang'), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);
    });

    testWidgets(
        'HutangDetailPage menampilkan progress dan pay button untuk active debt',
        (tester) async {
      final debt = Debt(
        id: 1,
        type: 'debt',
        personName: 'Test',
        principalAmount: 500000,
        remainingAmount: 200000,
        borrowedDate: _now2,
        recordingMode: 'note',
        status: 'active',
        createdDate: _now2,
        updatedDate: _now2,
      );
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_detail_page')), findsOneWidget);
      expect(find.byKey(const Key('debt_progress_bar')), findsOneWidget);
      expect(find.byKey(const Key('debt_pay_btn')), findsOneWidget);
    });

    testWidgets('Tap pay button menampilkan mode indicator yang konsisten',
        (tester) async {
      final debt = Debt(
        id: 1,
        type: 'debt',
        personName: 'Test',
        principalAmount: 500000,
        remainingAmount: 200000,
        borrowedDate: _now2,
        recordingMode: 'balance',
        status: 'active',
        createdDate: _now2,
        updatedDate: _now2,
      );
      await tester.pumpWidget(MaterialApp(
        home: HutangDetailPage(debt: debt, initialPayments: const []),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_pay_btn')));
      await tester.pumpAndSettle();

      // Mode indicator harus tampil di payment sheet (Task 7.2 hardening)
      expect(find.byKey(const Key('payment_mode_indicator')), findsOneWidget);
      expect(find.textContaining('Masuk ke saldo'), findsWidgets);
    });

    testWidgets('Quick menu ada dan berisi 3 item fitur baru', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen(skipInitialLoad: true)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_quick_menu')), findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const Key('home_quick_menu')),
            matching: find.text('Dompet'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const Key('home_quick_menu')),
            matching: find.text('Hutang/Piutang'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byKey(const Key('home_quick_menu')),
            matching: find.text('Pos keu..'),
          ),
          findsOneWidget);
    });

    testWidgets('Tab bar memiliki 5 tab dengan ikon Material', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen(skipInitialLoad: true)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // 5 tab dengan label text
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Statistik'), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Wish'), findsOneWidget);
      expect(find.text('Badge'), findsOneWidget);

      // Tab bar menggunakan Material icons (bukan emoji)
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
      expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);

      final homeIcon =
          tester.widget<Icon>(find.byIcon(Icons.home_rounded).first);
      final statsIcon =
          tester.widget<Icon>(find.byIcon(Icons.bar_chart_rounded).first);
      expect(homeIcon.size, 20);
      expect(statsIcon.size, 20);
    });

    testWidgets('sheet transaksi utama menampilkan drag handle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen(skipInitialLoad: true)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
    });

    testWidgets('sheet tambah dompet menampilkan drag handle', (tester) async {
      final wallets = [
        Wallet(id: 1, name: 'Cash', createdDate: _now2, updatedDate: _now2),
      ];
      await tester
          .pumpWidget(MaterialApp(home: DompetPage(initialWallets: wallets)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dompet_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
    });

    testWidgets('sheet tambah pos keuangan menampilkan drag handle',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: PosKeuanganPage(initialBuckets: [])));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet_drag_handle')), findsOneWidget);
    });

    testWidgets(
        'form transaksi menampilkan opsi bucket untuk expense dan income',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen(skipInitialLoad: true)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('transaction_bucket_section')), findsOneWidget);

      await tester.tap(find.text('Pemasukan').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('income_bucket_selector')), findsOneWidget);

      await tester.tap(find.text('Pengeluaran').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_bucket_dropdown')), findsOneWidget);
    });
  });
}
