// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:cashflow/main.dart';

void main() {
  const shortInteractionTimeout = Timeout(Duration(seconds: 5));

  Future<void> _pumpInteractionFrames(
    WidgetTester tester, {
    int frameCount = 8,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < frameCount; i++) {
      await tester.pump(step);
    }
  }

  Future<void> _pumpMainScreen(
    WidgetTester tester, {
    List<Transaction>? initialTransactions,
    List<Transaction>? initialAllTransactions,
    List<Wallet>? initialWallets,
    List<FinancialBucket>? initialBuckets,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          skipInitialLoad: true,
          initialTransactions: initialTransactions,
          initialAllTransactions: initialAllTransactions,
          initialWallets: initialWallets,
          initialBuckets: initialBuckets,
          initialHomeBalanceSourceType: 'total',
          initialHomeBalanceVisibilityHidden: false,
          persistHomeHeroPreferences: false,
        ),
      ),
    );
  }

  testWidgets('dashboard summary ignores note-only transactions',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final transactions = [
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Gaji',
        date: now,
        wallet: 'Cash',
        affectsBalance: true,
      ),
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Makanan',
        description: 'Makan',
        date: now,
        wallet: 'Cash',
        affectsBalance: true,
      ),
      Transaction(
        type: 'expense',
        amount: 999999,
        category: 'Catatan',
        description: 'Note only',
        date: now,
        wallet: 'Cash',
        affectsBalance: false,
      ),
    ];

    await _pumpMainScreen(
      tester,
      initialTransactions: transactions,
      initialAllTransactions: transactions,
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp 400.000'), findsOneWidget);
    expect(find.text('Rp -599.999'), findsNothing);
  });

  testWidgets('home defaults to bulanan and shows monthly income expense',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 15, 10);
    final outsideMonthSameYear = now.month > 1
        ? DateTime(now.year, now.month - 1, 15, 10)
        : DateTime(now.year, now.month + 1, 15, 10);

    final currentMonthTransactions = [
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Gaji bulan ini',
        date: currentMonthDate,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 80000,
        category: 'Belanja',
        description: 'Belanja bulan ini',
        date: currentMonthDate.add(const Duration(hours: 1)),
        wallet: 'Cash',
      ),
    ];
    final allTransactions = [
      ...currentMonthTransactions,
      Transaction(
        type: 'income',
        amount: 700000,
        category: 'Bonus',
        description: 'Bonus luar periode bulanan',
        date: outsideMonthSameYear,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Belanja',
        description: 'Belanja luar periode bulanan',
        date: outsideMonthSameYear.add(const Duration(hours: 1)),
        wallet: 'Cash',
      ),
    ];

    await _pumpMainScreen(
      tester,
      initialTransactions: currentMonthTransactions,
      initialAllTransactions: allTransactions,
    );
    await tester.pumpAndSettle();

    final monthlyLabel = tester.widget<Text>(find.text('Bulanan').first);
    expect(monthlyLabel.style?.color, Colors.white);
    expect(find.text('Rp 1.020.000'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsOneWidget);
    expect(find.text('Rp 80.000'), findsOneWidget);
    expect(find.text('Bonus luar periode bulanan'), findsNothing);
  });

  testWidgets('cashflow app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await _pumpMainScreen(tester);

    // Verify that the app starts correctly without depending on emoji copy.
    expect(find.byType(MainScreen), findsOneWidget);
  });

  testWidgets('home shell menampilkan tab baru dan navigasi inti tetap hidup',
      (WidgetTester tester) async {
    await _pumpMainScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Harian'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Tahunan'), findsOneWidget);
    expect(find.text('Mingguan'), findsNothing);
    expect(find.text('Rentang'), findsNothing);

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Statistik Keuangan'), findsOneWidget);
    expect(find.byIcon(Icons.view_week_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_month_outlined), findsOneWidget);
    expect(find.byIcon(Icons.date_range_outlined), findsWidgets);
    expect(find.text('Minggu'), findsOneWidget);
    expect(find.text('Bulan'), findsWidgets);
    expect(find.text('Tahun'), findsWidgets);
    expect(find.text('Rentang'), findsOneWidget);
    expect(find.text('Kategori Pengeluaran'), findsOneWidget);
    expect(find.text('Grafik Pengeluaran Minggu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom_nav_target_tabungan')));
    await tester.pumpAndSettle();

    expect(find.text('+ Goal Baru'), findsOneWidget);
    expect(find.text('Statistik Keuangan'), findsNothing);

    await tester.tap(find.byKey(const Key('bottom_nav_wishlist_belanja')));
    await tester.pumpAndSettle();

    expect(find.text('+ Tambah Item'), findsOneWidget);
  });

  testWidgets('bottom nav respects bottom system inset',
      (WidgetTester tester) async {
    const mediaQueryData = MediaQueryData(
      size: Size(800, 600),
      viewPadding: EdgeInsets.only(bottom: 24),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: mediaQueryData,
        child: MaterialApp(
          home: MainScreen(
            skipInitialLoad: true,
            initialHomeBalanceSourceType: 'total',
            initialHomeBalanceVisibilityHidden: false,
            persistHomeHeroPreferences: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dockRect = tester.getRect(find.byKey(const Key('bottom_nav_bar')));
    expect(
      dockRect.bottom,
      lessThanOrEqualTo(
        mediaQueryData.size.height - mediaQueryData.viewPadding.bottom,
      ),
    );
  });

  testWidgets('bottom nav labels stay on one line on narrow widths',
      (WidgetTester tester) async {
    const mediaQueryData = MediaQueryData(size: Size(360, 800));

    await tester.pumpWidget(
      MediaQuery(
        data: mediaQueryData,
        child: MaterialApp(
          home: MainScreen(
            skipInitialLoad: true,
            initialHomeBalanceSourceType: 'total',
            initialHomeBalanceVisibilityHidden: false,
            persistHomeHeroPreferences: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final berandaText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_beranda')),
        matching: find.text('Beranda'),
      ),
    );
    final statistikText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_statistik')),
        matching: find.text('Statistik'),
      ),
    );

    expect(berandaText.maxLines, 1);
    expect(berandaText.softWrap, isFalse);
    expect(statistikText.maxLines, 1);
    expect(statistikText.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history metadata uses larger readable typography',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final tx = Transaction(
      type: 'expense',
      amount: 150000,
      category: 'Makanan',
      description: 'Makan siang',
      date: now,
      wallet: 'Cash',
    );

    await _pumpMainScreen(
      tester,
      initialTransactions: [tx],
      initialAllTransactions: [tx],
    );
    await tester.pumpAndSettle();

    final categoryText = tester.widget<Text>(find.text('Makanan').last);
    final walletText = tester.widget<Text>(find.text('• Cash'));
    final dateText = tester.widget<Text>(
      find.text(DateFormat('dd MMM yyyy, HH:mm').format(now)),
    );

    expect(categoryText.style?.fontSize, 10);
    expect(walletText.style?.fontSize, 10);
    expect(dateText.style?.fontSize, 10);
  });

  testWidgets(
      'sheet tambah wishlist menampilkan feedback lokal untuk validasi wajib',
      (WidgetTester tester) async {
    await _pumpMainScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottom_nav_wishlist_belanja')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Tambah Item'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah ke Wishlist'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist_sheet_feedback')), findsOneWidget);
    expect(find.text('Nama barang tidak boleh kosong!'), findsOneWidget);
  });

  testWidgets('debt form fields stand out clearly inside the sheet',
      (WidgetTester tester) async {
    final now = DateTime(2026);
    await tester.pumpWidget(MaterialApp(
      home: HutangPiutangPage(
        initialDebts: const [],
        initialWallets: [
          Wallet(
            id: 1,
            name: 'Cash',
            iconKey: 'cash',
            createdDate: now,
            updatedDate: now,
          ),
        ],
        initialBuckets: [
          FinancialBucket(
            id: 1,
            name: 'Dana Darurat',
            allocationPercentage: 100,
            currentBalance: 0,
            createdDate: now,
            updatedDate: now,
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('debt_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_form_surface')), findsNothing);
    final personField =
        tester.widget<TextField>(find.byKey(const Key('debt_person_field')));
    final amountField =
        tester.widget<TextField>(find.byKey(const Key('debt_amount_field')));
    expect(personField.decoration?.filled, isTrue);
    expect(amountField.decoration?.filled, isTrue);
  });

  testWidgets('range filter only opens picker from the range action button',
      (WidgetTester tester) async {
    await _pumpMainScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rentang'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Rentang Tanggal'), findsOneWidget);
    expect(find.text('Pilih rentang tanggal dulu'), findsOneWidget);
    expect(find.text('Kategori Pengeluaran'), findsNothing);
  });

  testWidgets('tap transaction membuka detail transaksi dengan aksi edit hapus',
      (WidgetTester tester) async {
    final transaction = Transaction(
      id: 1,
      type: 'expense',
      amount: 120000,
      category: 'Belanja',
      description: 'Belanja mingguan',
      date: DateTime(2026, 8, 9, 10, 30),
      wallet: 'Cash',
    );

    await _pumpMainScreen(
      tester,
      initialTransactions: [transaction],
      initialAllTransactions: [transaction],
    );
    await _pumpInteractionFrames(tester);

    final transactionFinder = find.text('Belanja mingguan');
    await tester.ensureVisible(transactionFinder);
    await tester.tap(transactionFinder);
    await _pumpInteractionFrames(tester);

    expect(find.byKey(const Key('transaction_detail_page')), findsOneWidget);
    expect(
        find.byKey(const Key('transaction_detail_edit_btn')), findsOneWidget);
    expect(
        find.byKey(const Key('transaction_detail_delete_btn')), findsOneWidget);
  }, timeout: shortInteractionTimeout);

  testWidgets('swipe kiri pada card transaksi membuka form edit',
      (WidgetTester tester) async {
    final transaction = Transaction(
      id: 2,
      type: 'expense',
      amount: 200000,
      category: 'Belanja',
      description: 'Belanja Ifhaa',
      date: DateTime(2026, 8, 9, 10, 30),
      wallet: 'Cash',
    );

    await _pumpMainScreen(
      tester,
      initialTransactions: [transaction],
      initialAllTransactions: [transaction],
    );
    await _pumpInteractionFrames(tester);

    final transactionFinder = find.text('Belanja Ifhaa');
    await tester.ensureVisible(transactionFinder);
    await tester.drag(transactionFinder, const Offset(-600, 0));
    await _pumpInteractionFrames(tester);

    expect(find.text('Edit Transaksi'), findsOneWidget);
    expect(find.text('Belanja Ifhaa'), findsWidgets);
  }, timeout: shortInteractionTimeout);

  testWidgets('swipe kanan pada card transaksi membuka dialog hapus',
      (WidgetTester tester) async {
    final transaction = Transaction(
      id: 3,
      type: 'expense',
      amount: 80000,
      category: 'Belanja',
      description: 'Belanja cepat',
      date: DateTime(2026, 8, 9, 10, 30),
      wallet: 'Cash',
    );

    await _pumpMainScreen(
      tester,
      initialTransactions: [transaction],
      initialAllTransactions: [transaction],
    );
    await _pumpInteractionFrames(tester);

    final transactionFinder = find.text('Belanja cepat');
    await tester.ensureVisible(transactionFinder);
    await tester.drag(transactionFinder, const Offset(600, 0));
    await _pumpInteractionFrames(tester);

    expect(find.text('Hapus Transaksi? 🗑️'), findsOneWidget);
    expect(find.text('Kamu yakin mau hapus transaksi ini?'), findsOneWidget);
  }, timeout: shortInteractionTimeout);
}
