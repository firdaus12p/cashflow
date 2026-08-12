import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/badges/models/user_badge.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/home/helpers/home_helpers.dart';
import 'package:cashflow/features/transactions/models/transaction.dart';

void main() {
  group('Home helpers', () {
    test('resolveHomeFilterRange default ke monthly dan yearly tetap benar',
        () {
      final referenceDate = DateTime(2026, 8, 15, 10, 30);

      final defaultRange = resolveHomeFilterRange('unknown', referenceDate);
      expect(defaultRange.start, DateTime(2026, 8, 1));
      expect(defaultRange.end, DateTime(2026, 8, 31, 23, 59, 59));

      final yearlyRange = resolveHomeFilterRange('yearly', referenceDate);
      expect(yearlyRange.start, DateTime(2026, 1, 1));
      expect(yearlyRange.end, DateTime(2026, 12, 31, 23, 59, 59));
    });

    test('calculateMonthlyExpenseForInsight memakai filter bulan dan wallet',
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
        Transaction(
          type: 'expense',
          amount: 777777,
          category: 'Catatan',
          description: 'Note only',
          date: DateTime(2026, 8, 12, 12),
          wallet: 'Cash',
          affectsBalance: false,
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

    test('calculateBalanceForWallet memakai all-time data dan wallet filter',
        () {
      final transactions = [
        Transaction(
          type: 'income',
          amount: 500000,
          category: 'Gaji',
          description: 'Gaji bulan ini',
          date: DateTime(2026, 8, 15),
          wallet: 'Cash',
        ),
        Transaction(
          type: 'expense',
          amount: 80000,
          category: 'Belanja',
          description: 'Belanja bulan ini',
          date: DateTime(2026, 8, 15, 12),
          wallet: 'Cash',
        ),
        Transaction(
          type: 'income',
          amount: 700000,
          category: 'Bonus',
          description: 'Bonus bulan lalu',
          date: DateTime(2026, 7, 15),
          wallet: 'Cash',
        ),
        Transaction(
          type: 'expense',
          amount: 100000,
          category: 'Belanja',
          description: 'Belanja bulan lalu',
          date: DateTime(2026, 7, 16),
          wallet: 'Cash',
        ),
        Transaction(
          type: 'income',
          amount: 999999,
          category: 'Gaji',
          description: 'Wallet lain',
          date: DateTime(2026, 8, 17),
          wallet: 'Bank',
        ),
        Transaction(
          type: 'expense',
          amount: 123456,
          category: 'Catatan',
          description: 'Tidak memengaruhi saldo',
          date: DateTime(2026, 8, 18),
          wallet: 'Cash',
          affectsBalance: false,
        ),
      ];

      expect(calculateBalanceForWallet(transactions), 2019999);
      expect(
        calculateBalanceForWallet(transactions, selectedWallet: 'Cash'),
        1020000,
      );
    });

    test(
        'projectTransactionsForWalletScope memecah income multi-dompet sesuai alokasi wallet',
        () {
      final now = DateTime(2026, 8, 15);
      final transaction = Transaction(
        id: 99,
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Gaji lintas dompet',
        date: now,
        wallet: 'Multi Dompet',
        walletNameSnapshot: 'Multi Dompet',
      );
      final projected = projectTransactionsForWalletScope(
        [transaction],
        walletName: 'Cash',
        walletId: 1,
        allocationsByTransactionId: {
          99: [
            TransactionBucketAllocation(
              transactionId: 99,
              bucketId: 11,
              normalizedPercentage: 60,
              allocatedAmount: 300000,
              role: 'target',
              createdDate: now,
            ),
            TransactionBucketAllocation(
              transactionId: 99,
              bucketId: 22,
              normalizedPercentage: 40,
              allocatedAmount: 200000,
              role: 'target',
              createdDate: now,
            ),
          ],
        },
        bucketWalletById: const {11: 1, 22: 2},
      );

      expect(projected, hasLength(1));
      expect(projected.single.id, 99);
      expect(projected.single.wallet, 'Cash');
      expect(projected.single.amount, 300000);
      expect(isProjectedWalletScopeTransaction(projected.single), isTrue);
    });

    test('projectTransactionsForWalletScope mempertahankan transaksi biasa',
        () {
      final transaction = Transaction(
        id: 7,
        type: 'expense',
        amount: 80000,
        category: 'Belanja',
        description: 'Belanja biasa',
        date: DateTime(2026, 8, 15),
        wallet: 'Cash',
        walletId: 1,
        walletNameSnapshot: 'Cash',
      );

      final projected = projectTransactionsForWalletScope(
        [transaction],
        walletName: 'Cash',
        walletId: 1,
        allocationsByTransactionId: const {},
        bucketWalletById: const {},
      );

      expect(projected, hasLength(1));
      expect(projected.single, same(transaction));
      expect(isProjectedWalletScopeTransaction(projected.single), isFalse);
    });

    test('hasSavingBadgeForPeriod mengecek bulan dan tahun sekaligus', () {
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

    test('formatSelectedDateRangeLabel menangani rentang satu dan beda bulan',
        () {
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
  });
}
