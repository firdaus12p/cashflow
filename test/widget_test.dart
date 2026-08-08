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

  testWidgets('PinkyCash app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CuteMoneyTrackerApp());

    // Verify that the app starts correctly
    expect(find.text('Halo Cantik! 💕'), findsOneWidget);
  });
}
