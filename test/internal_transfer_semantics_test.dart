// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:pinkycash_app/main.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  test('calculateMonthlyExpenseForInsight mengabaikan transfer internal', () {
    final transactions = [
      Transaction(
        type: 'expense',
        amount: 150000,
        category: 'Belanja',
        description: 'Belanja nyata',
        date: now,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'expense',
        amount: 100000,
        category: 'Transfer Internal',
        description: 'Transfer ke Bank',
        date: now,
        wallet: 'Cash',
      ),
    ];

    expect(calculateMonthlyExpenseForInsight(transactions, now), 150000);
  });

  test('userVisibleBalanceTransactions mengecualikan transfer internal', () {
    final transactions = [
      Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Pemasukan nyata',
        date: now,
        wallet: 'Cash',
      ),
      Transaction(
        type: 'income',
        amount: 100000,
        category: 'Transfer Internal',
        description: 'Transfer dari Cash',
        date: now,
        wallet: 'Bank',
      ),
    ];

    final visible = userVisibleBalanceTransactions(transactions).toList();
    expect(visible.length, 1);
    expect(visible.single.category, 'Gaji');
  });
}
