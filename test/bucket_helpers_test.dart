import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/buckets/helpers/bucket_helpers.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';

void main() {
  final now = DateTime(2026);

  FinancialBucket bucket(int id, double pct, {double balance = 0}) =>
      FinancialBucket(
        id: id,
        name: 'Bucket $id',
        allocationPercentage: pct,
        currentBalance: balance,
        createdDate: now,
        updatedDate: now,
      );

  FinancialBucket bucketWithWallet(
    int id,
    double pct, {
    required int walletId,
    double balance = 0,
  }) =>
      FinancialBucket(
        id: id,
        name: 'Bucket $id',
        walletId: walletId,
        allocationPercentage: pct,
        currentBalance: balance,
        createdDate: now,
        updatedDate: now,
      );

  group('validateBucketPercentages — BR-08', () {
    test('total tepat 100% diterima', () {
      expect(
        validateBucketPercentages([bucket(1, 60), bucket(2, 40)]),
        isTrue,
      );
    });

    test('satu pos 100% diterima', () {
      expect(validateBucketPercentages([bucket(1, 100)]), isTrue);
    });

    test('tiga pos dengan pembulatan floating point diterima', () {
      expect(
        validateBucketPercentages(
          [bucket(1, 33.33), bucket(2, 33.33), bucket(3, 33.34)],
        ),
        isTrue,
      );
    });

    test('total kurang dari 100% ditolak', () {
      expect(
        validateBucketPercentages([bucket(1, 50), bucket(2, 30)]),
        isFalse,
      );
    });

    test('total lebih dari 100% ditolak', () {
      expect(
        validateBucketPercentages([bucket(1, 60), bucket(2, 50)]),
        isFalse,
      );
    });

    test('daftar kosong ditolak', () {
      expect(validateBucketPercentages([]), isFalse);
    });
  });

  group('normalizeSubsetAllocation — BR-09', () {
    test('subset dua pos dari tiga dinormalisasi ke 100%', () {
      final subset = [bucket(1, 50), bucket(3, 20)];
      final result = normalizeSubsetAllocation(subset);

      expect(result.keys, containsAll([1, 3]));
      expect(result[1], closeTo(71.43, 0.01));
      expect(result[3], closeTo(28.57, 0.01));
    });

    test('subset satu pos menjadi 100%', () {
      final result = normalizeSubsetAllocation([bucket(2, 30)]);
      expect(result[2], closeTo(100.0, 0.01));
    });

    test('subset semua pos mempertahankan persentase asli', () {
      final subset = [bucket(1, 60), bucket(2, 40)];
      final result = normalizeSubsetAllocation(subset);
      expect(result[1], closeTo(60.0, 0.01));
      expect(result[2], closeTo(40.0, 0.01));
    });

    test('jumlah normalized percentages selalu 100%', () {
      final subset = [bucket(1, 50), bucket(2, 30), bucket(3, 20)];
      final result = normalizeSubsetAllocation(subset);
      final total = result.values.fold(0.0, (sum, value) => sum + value);
      expect(total, closeTo(100.0, 0.01));
    });

    test('subset kosong mengembalikan map kosong', () {
      expect(normalizeSubsetAllocation([]), isEmpty);
    });
  });

  group('allocateIncomeToBuckets', () {
    test('income 1 juta dialokasikan ke dua pos sesuai persentase normalized',
        () {
      final subset = [bucket(1, 50), bucket(2, 20)];
      const amount = 1000000.0;
      final allocations = allocateIncomeToBuckets(amount, subset);

      final total = allocations.values.fold(0.0, (sum, value) => sum + value);
      expect(total, closeTo(amount, 0.01));
      expect(allocations[1]!, greaterThan(allocations[2]!));
    });

    test('satu pos menerima seluruh income', () {
      final subset = [bucket(5, 100)];
      final allocations = allocateIncomeToBuckets(500000, subset);
      expect(allocations[5], closeTo(500000, 0.01));
    });

    test('income nol menghasilkan alokasi nol untuk semua pos', () {
      final subset = [bucket(1, 60), bucket(2, 40)];
      final allocations = allocateIncomeToBuckets(0, subset);
      expect(allocations.values.every((value) => value == 0.0), isTrue);
    });
  });

  group('bucketsShareSameWallet — FEAT-07', () {
    test('dua bucket dalam wallet yang sama diterima', () {
      expect(
        bucketsShareSameWallet([
          bucketWithWallet(1, 60, walletId: 1),
          bucketWithWallet(2, 40, walletId: 1),
        ]),
        isTrue,
      );
    });

    test('bucket lintas wallet ditolak', () {
      expect(
        bucketsShareSameWallet([
          bucketWithWallet(1, 60, walletId: 1),
          bucketWithWallet(2, 40, walletId: 2),
        ]),
        isFalse,
      );
    });

    test('subset kosong ditolak', () {
      expect(bucketsShareSameWallet(const []), isFalse);
    });
  });
}
