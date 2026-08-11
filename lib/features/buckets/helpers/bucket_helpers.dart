import '../../../core/constants/app_constants.dart';
import '../models/bucket_models.dart';

double getBucketPercentageTotal(List<FinancialBucket> buckets) {
  return buckets.fold(0.0, (sum, bucket) => sum + bucket.allocationPercentage);
}

bool validateBucketPercentages(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  final total = getBucketPercentageTotal(buckets);
  return (total - 100.0).abs() <= bucketPercentageTolerance;
}

bool canSaveBucketPercentages(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  return getBucketPercentageTotal(buckets) <= 100.0 + bucketPercentageTolerance;
}

bool hasIncompleteBucketConfiguration(List<FinancialBucket> buckets) {
  return buckets.isNotEmpty && !validateBucketPercentages(buckets);
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
