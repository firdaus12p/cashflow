import '../../../core/constants/app_constants.dart';
import '../models/bucket_models.dart';

typedef BucketReconciliationPreview = ({
  double walletBalance,
  double bucketBalanceTotal,
  double delta,
  bool canApply,
  Map<int, double> balanceChanges,
  Map<int, double> resultingBalances,
});

List<FinancialBucket> activeBucketsOnly(List<FinancialBucket> buckets) {
  return buckets.where((bucket) => !bucket.isArchived).toList(growable: false);
}

double getBucketPercentageTotal(List<FinancialBucket> buckets) {
  return activeBucketsOnly(buckets).fold(
    0.0,
    (sum, bucket) => sum + bucket.allocationPercentage,
  );
}

bool validateBucketPercentages(List<FinancialBucket> buckets) {
  if (activeBucketsOnly(buckets).isEmpty) return false;
  final total = getBucketPercentageTotal(buckets);
  return (total - 100.0).abs() <= bucketPercentageTolerance;
}

bool canSaveBucketPercentages(List<FinancialBucket> buckets) {
  if (activeBucketsOnly(buckets).isEmpty) return false;
  return getBucketPercentageTotal(buckets) <= 100.0 + bucketPercentageTolerance;
}

bool hasIncompleteBucketConfiguration(List<FinancialBucket> buckets) {
  final activeBuckets = activeBucketsOnly(buckets);
  return activeBuckets.isNotEmpty && !validateBucketPercentages(activeBuckets);
}

Map<int, double> normalizeSubsetAllocation(List<FinancialBucket> subset) {
  if (subset.isEmpty) return {};
  final totalPct = subset.fold(
    0.0,
    (sum, bucket) => sum + bucket.allocationPercentage,
  );
  return {
    for (final bucket in subset)
      bucket.id!: (bucket.allocationPercentage / totalPct) * 100,
  };
}

Map<int, double> allocateIncomeToBuckets(
  double amount,
  List<FinancialBucket> subset,
) {
  if (subset.isEmpty || amount == 0) {
    return {for (final bucket in subset) bucket.id!: 0.0};
  }
  final normalized = normalizeSubsetAllocation(subset);
  return {
    for (final entry in normalized.entries)
      entry.key: amount * entry.value / 100,
  };
}

bool bucketsShareSameWallet(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  final firstWalletId = buckets.first.walletId;
  if (firstWalletId == null) return false;
  return buckets.every((bucket) => bucket.walletId == firstWalletId);
}

BucketReconciliationPreview previewBucketReconciliation({
  required double walletBalance,
  required List<FinancialBucket> activeBucketsForWallet,
  required bool isReactivation,
}) {
  final buckets = activeBucketsOnly(activeBucketsForWallet)
      .where((bucket) => bucket.id != null)
      .toList(growable: false);
  final bucketBalanceTotal = buckets.fold<double>(
    0,
    (sum, bucket) => sum + bucket.currentBalance,
  );
  final delta = walletBalance - bucketBalanceTotal;

  if (buckets.isEmpty) {
    return (
      walletBalance: walletBalance,
      bucketBalanceTotal: bucketBalanceTotal,
      delta: delta,
      canApply: delta.abs() <= bucketPercentageTolerance,
      balanceChanges: const {},
      resultingBalances: const {},
    );
  }

  final balanceChanges = <int, double>{};
  final resultingBalances = <int, double>{};

  if (delta.abs() <= bucketPercentageTolerance) {
    for (final bucket in buckets) {
      resultingBalances[bucket.id!] = bucket.currentBalance;
    }
    return (
      walletBalance: walletBalance,
      bucketBalanceTotal: bucketBalanceTotal,
      delta: 0,
      canApply: true,
      balanceChanges: balanceChanges,
      resultingBalances: resultingBalances,
    );
  }

  if (delta > 0) {
    final totalAllocation = buckets.fold<double>(
      0,
      (sum, bucket) => sum + bucket.allocationPercentage,
    );
    if (totalAllocation <= bucketPercentageTolerance) {
      return (
        walletBalance: walletBalance,
        bucketBalanceTotal: bucketBalanceTotal,
        delta: delta,
        canApply: false,
        balanceChanges: const {},
        resultingBalances: {
          for (final bucket in buckets) bucket.id!: bucket.currentBalance,
        },
      );
    }

    final normalized = normalizeSubsetAllocation(buckets);
    for (final bucket in buckets) {
      final bucketId = bucket.id!;
      final change = delta * (normalized[bucketId] ?? 0) / 100;
      balanceChanges[bucketId] = change;
      resultingBalances[bucketId] = bucket.currentBalance + change;
    }
  } else {
    if (!isReactivation || bucketBalanceTotal <= bucketPercentageTolerance) {
      return (
        walletBalance: walletBalance,
        bucketBalanceTotal: bucketBalanceTotal,
        delta: delta,
        canApply: false,
        balanceChanges: const {},
        resultingBalances: {
          for (final bucket in buckets) bucket.id!: bucket.currentBalance,
        },
      );
    }

    for (final bucket in buckets) {
      final bucketId = bucket.id!;
      final balanceShare = bucket.currentBalance / bucketBalanceTotal;
      final change = delta * balanceShare;
      balanceChanges[bucketId] = change;
      resultingBalances[bucketId] = bucket.currentBalance + change;
    }
  }

  final canApply = resultingBalances.values
      .every((balance) => balance >= -bucketPercentageTolerance);

  return (
    walletBalance: walletBalance,
    bucketBalanceTotal: bucketBalanceTotal,
    delta: delta,
    canApply: canApply,
    balanceChanges: balanceChanges,
    resultingBalances: resultingBalances,
  );
}
