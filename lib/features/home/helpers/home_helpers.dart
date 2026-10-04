import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatters.dart';
import '../../badges/models/user_badge.dart';
import '../../buckets/models/bucket_models.dart';
import '../../transactions/models/transaction.dart';
import '../../wallets/models/wallet.dart';

const String _projectedWalletTransactionSnapshotPrefix =
    '__wallet_scope_projection__:';

({DateTime start, DateTime end}) resolveHomeFilterRange(
  String filter,
  DateTime referenceDate,
) {
  switch (filter) {
    case 'daily':
      return (
        start: DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
        ),
        end: DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
          23,
          59,
          59,
        ),
      );
    case 'yearly':
      return (
        start: DateTime(referenceDate.year, 1, 1),
        end: DateTime(referenceDate.year, 12, 31, 23, 59, 59),
      );
    case 'monthly':
    default:
      return (
        start: DateTime(referenceDate.year, referenceDate.month, 1),
        end: DateTime(
          referenceDate.year,
          referenceDate.month + 1,
          0,
          23,
          59,
          59,
        ),
      );
  }
}

double calculateMonthlyExpenseForInsight(
  List<Transaction> transactions,
  DateTime referenceDate, {
  String selectedWallet = 'All',
}) {
  final thisMonthStart = DateTime(referenceDate.year, referenceDate.month, 1);
  final thisMonthEnd =
      DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);

  return transactions
      .where((transaction) =>
          transaction.affectsBalance &&
          transaction.category != internalTransferCategory &&
          transaction.type == 'expense' &&
          (selectedWallet == 'All' || transaction.wallet == selectedWallet) &&
          transaction.date
              .isAfter(thisMonthStart.subtract(const Duration(seconds: 1))) &&
          transaction.date
              .isBefore(thisMonthEnd.add(const Duration(seconds: 1))))
      .fold(0.0, (sum, transaction) => sum + transaction.amount);
}

double calculateBalanceForWallet(
  Iterable<Transaction> transactions, {
  String selectedWallet = 'All',
}) {
  return transactions
      .where((transaction) =>
          transaction.affectsBalance &&
          (selectedWallet == 'All' || transaction.wallet == selectedWallet))
      .fold<double>(0, (sum, transaction) {
    return sum +
        (transaction.type == 'income'
            ? transaction.amount
            : -transaction.amount);
  });
}

bool isProjectedWalletScopeTransaction(Transaction transaction) {
  return transaction.walletNameSnapshot.startsWith(
    _projectedWalletTransactionSnapshotPrefix,
  );
}

double resolveWalletScopedTransactionAmount(
  Transaction transaction,
  List<TransactionBucketAllocation> allocations,
  Map<int, int?> bucketWalletById, {
  required int? walletId,
}) {
  if (walletId == null) return 0;

  final allocationRole = transaction.type == 'income'
      ? 'target'
      : transaction.type == 'expense'
          ? 'source'
          : null;
  if (allocationRole == null) return 0;

  return allocations
      .where((allocation) =>
          allocation.role == allocationRole &&
          bucketWalletById[allocation.bucketId] == walletId)
      .fold<double>(0, (sum, allocation) => sum + allocation.allocatedAmount);
}

Transaction? projectTransactionForWalletScope(
  Transaction transaction, {
  required String walletName,
  required int? walletId,
  List<TransactionBucketAllocation> allocations = const [],
  Map<int, int?> bucketWalletById = const {},
}) {
  final allocatedAmount = resolveWalletScopedTransactionAmount(
    transaction,
    allocations,
    bucketWalletById,
    walletId: walletId,
  );
  final normalizedAllocatedAmount = normalizeRupiahAmount(allocatedAmount);
  if (compareRupiahAmount(normalizedAllocatedAmount, 0) > 0) {
    final keepsOriginalWallet = transaction.wallet == walletName &&
        transaction.walletId == walletId &&
        compareRupiahAmount(transaction.amount, normalizedAllocatedAmount) == 0;
    if (keepsOriginalWallet) {
      return transaction;
    }

    final snapshotLabel = transaction.walletNameSnapshot.isEmpty
        ? transaction.wallet
        : transaction.walletNameSnapshot;
    return Transaction(
      id: transaction.id,
      type: transaction.type,
      amount: normalizedAllocatedAmount,
      category: transaction.category,
      description: transaction.description,
      date: transaction.date,
      wallet: walletName,
      walletId: walletId,
      walletNameSnapshot:
          '$_projectedWalletTransactionSnapshotPrefix$snapshotLabel',
      affectsBalance: transaction.affectsBalance,
    );
  }

  final matchesWallet = walletId != null
      ? transaction.walletId == walletId || transaction.wallet == walletName
      : transaction.wallet == walletName;
  if (!matchesWallet) {
    return null;
  }
  return transaction;
}

List<Transaction> projectTransactionsForWalletScope(
  Iterable<Transaction> transactions, {
  required String walletName,
  required int? walletId,
  required Map<int, List<TransactionBucketAllocation>>
      allocationsByTransactionId,
  required Map<int, int?> bucketWalletById,
}) {
  return transactions
      .map(
        (transaction) => projectTransactionForWalletScope(
          transaction,
          walletName: walletName,
          walletId: walletId,
          allocations: transaction.id == null
              ? const []
              : (allocationsByTransactionId[transaction.id!] ?? const []),
          bucketWalletById: bucketWalletById,
        ),
      )
      .whereType<Transaction>()
      .toList(growable: false);
}

Iterable<Transaction> affectingTransactions(
  Iterable<Transaction> transactions,
) {
  return transactions.where((transaction) => transaction.affectsBalance);
}

Iterable<Transaction> userVisibleBalanceTransactions(
  Iterable<Transaction> transactions,
) {
  return transactions.where((transaction) =>
      transaction.affectsBalance &&
      transaction.category != internalTransferCategory);
}

bool hasSavingBadgeForPeriod(List<UserBadge> badges, DateTime referenceDate) {
  return badges.any((badge) =>
      badge.type == 'saving' &&
      badge.earnedDate.year == referenceDate.year &&
      badge.earnedDate.month == referenceDate.month);
}

String formatSelectedDateRangeLabel(DateTimeRange range) {
  final startMonth = DateFormat('MMM').format(range.start);
  final endMonth = DateFormat('MMM').format(range.end);

  if (range.start.year == range.end.year &&
      range.start.month == range.end.month) {
    return '$startMonth ${range.start.day} - ${range.end.day}, ${range.end.year}';
  }

  if (range.start.year == range.end.year) {
    return '$startMonth ${range.start.day} - $endMonth ${range.end.day}, ${range.end.year}';
  }

  return '$startMonth ${range.start.day}, ${range.start.year} - $endMonth ${range.end.day}, ${range.end.year}';
}

typedef HomeBalanceSourceResolution = ({String type, int? id, String title});

Wallet? findWalletInList(Iterable<Wallet> wallets, int? walletId) {
  if (walletId == null) return null;
  for (final wallet in wallets) {
    if (wallet.id == walletId) return wallet;
  }
  return null;
}

FinancialBucket? findBucketInList(
  Iterable<FinancialBucket> buckets,
  int? bucketId,
) {
  if (bucketId == null) return null;
  for (final bucket in buckets) {
    if (bucket.id == bucketId) return bucket;
  }
  return null;
}

HomeBalanceSourceResolution resolveHomeBalanceSource(
  String preferenceType,
  int? preferenceId,
  List<Wallet> wallets,
  List<FinancialBucket> buckets,
) {
  switch (preferenceType) {
    case 'wallet':
      final wallet = findWalletInList(wallets, preferenceId);
      if (wallet != null) {
        return (type: 'wallet', id: wallet.id, title: 'Saldo ${wallet.name}');
      }
      break;
    case 'bucket':
      final bucket = findBucketInList(buckets, preferenceId);
      if (bucket != null) {
        return (type: 'bucket', id: bucket.id, title: 'Saldo ${bucket.name}');
      }
      break;
  }

  return (type: 'total', id: null, title: 'Total Saldo');
}
