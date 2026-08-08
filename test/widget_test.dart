import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinkycash_app/main.dart';

void main() {
  test('calculateMonthlyExpenseForInsight uses monthly data and wallet filter',
      () {
    final now = DateTime(2026, 8, 15);
    final transactions = [
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Makanan',
        description: 'Sarapan',
        date: DateTime(2026, 8, 1, 8),
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 200000,
        category: 'Belanja',
        description: 'Belanja bulanan',
        date: DateTime(2026, 8, 10, 9),
        wallet: 'Bank',
      ),
      Transaction(
        type: 'expense',
        amount: 999999,
        category: 'Transport',
        description: 'Bulan lalu',
        date: DateTime(2026, 7, 31, 23, 59),
        wallet: 'Cash',
      ),
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Gaji',
        date: DateTime(2026, 8, 3, 12),
        wallet: 'Cash',
      ),
    ];

    expect(calculateMonthlyExpenseForInsight(transactions, now), 300000);
    expect(
      calculateMonthlyExpenseForInsight(
        transactions,
        now,
        selectedWallet: 'Cash',
      ),
      100000,
    );
  });

  test('hasSavingBadgeForPeriod checks month and year together', () {
    final badges = [
      UserBadge(
        name: 'Bulan lalu',
        description: 'Badge dari tahun sebelumnya',
        emoji: '🏆',
        earnedDate: DateTime(2025, 8, 2),
        type: 'saving',
      ),
      UserBadge(
        name: 'Periode lain',
        description: 'Badge bulan berbeda',
        emoji: '🏆',
        earnedDate: DateTime(2026, 7, 2),
        type: 'saving',
      ),
    ];

    expect(hasSavingBadgeForPeriod(badges, DateTime(2026, 8, 10)), isFalse);

    badges.add(
      UserBadge(
        name: 'Periode aktif',
        description: 'Badge bulan dan tahun yang sama',
        emoji: '🏆',
        earnedDate: DateTime(2026, 8, 3),
        type: 'saving',
      ),
    );

    expect(hasSavingBadgeForPeriod(badges, DateTime(2026, 8, 10)), isTrue);
  });

  test('formatSelectedDateRangeLabel formats same and cross-month ranges', () {
    expect(
      formatSelectedDateRangeLabel(
        DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 8),
        ),
      ),
      'Aug 1 - 8, 2026',
    );

    expect(
      formatSelectedDateRangeLabel(
        DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 9, 5),
        ),
      ),
      'Aug 1 - Sep 5, 2026',
    );
  });

  testWidgets('PinkyCash app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CuteMoneyTrackerApp());

    // Verify that the app starts correctly
    expect(find.text('Halo Cantik! 💕'), findsOneWidget);
  });

  testWidgets('home shows transaction history and second tab shows statistics',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CuteMoneyTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Transaksi 📝'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Harian'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Tahunan'), findsOneWidget);
    expect(find.text('Mingguan'), findsNothing);
    expect(find.text('Rentang'), findsNothing);

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Statistik Keuangan 📊'), findsOneWidget);
    expect(find.text('Mingguan'), findsOneWidget);
    expect(find.text('Bulanan'), findsWidgets);
    expect(find.text('Tahunan'), findsWidgets);
    expect(find.text('Rentang'), findsOneWidget);
    expect(find.text('Kategori Pengeluaran 🛍️'), findsOneWidget);
    expect(find.text('Grafik Pengeluaran Mingguan 📊'), findsOneWidget);

    await tester.tap(find.text('Badge'));
    await tester.pumpAndSettle();

    expect(find.text('Badge & Pencapaian 🏆'), findsOneWidget);
    expect(find.text('Badge Kamu 🎖️'), findsOneWidget);
    expect(find.text('Statistik Keuangan 📊'), findsNothing);
  });

  testWidgets('range filter only opens picker from the range action button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CuteMoneyTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rentang'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Rentang Tanggal'), findsOneWidget);
    expect(find.text('Pilih rentang tanggal dulu'), findsOneWidget);
    expect(find.text('Kategori Pengeluaran 🛍️'), findsNothing);
  });
}
