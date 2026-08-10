// ignore_for_file: depend_on_referenced_packages

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

  // ---------------------------------------------------------------------------
  // validateBucketPercentages — BR-08
  // gap: fungsi belum ada — ditambahkan di Task 5.2
  // ---------------------------------------------------------------------------

  final _now = DateTime(2026);

  FinancialBucket _bucket(int id, double pct, {double balance = 0}) =>
      FinancialBucket(
        id: id,
        name: 'Bucket $id',
        allocationPercentage: pct,
        currentBalance: balance,
        createdDate: _now,
        updatedDate: _now,
      );

  FinancialBucket _bucketWithWallet(
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
        createdDate: _now,
        updatedDate: _now,
      );

  group('validateBucketPercentages — BR-08', () {
    test('total tepat 100% diterima', () {
      expect(
        validateBucketPercentages([_bucket(1, 60), _bucket(2, 40)]),
        isTrue,
      );
    });

    test('satu pos 100% diterima', () {
      expect(validateBucketPercentages([_bucket(1, 100)]), isTrue);
    });

    test('tiga pos dengan pembulatan floating point diterima', () {
      // 33.33 + 33.33 + 33.34 = 100.00
      expect(
        validateBucketPercentages(
            [_bucket(1, 33.33), _bucket(2, 33.33), _bucket(3, 33.34)]),
        isTrue,
      );
    });

    test('total kurang dari 100% ditolak', () {
      expect(
        validateBucketPercentages([_bucket(1, 50), _bucket(2, 30)]),
        isFalse,
      );
    });

    test('total lebih dari 100% ditolak', () {
      expect(
        validateBucketPercentages([_bucket(1, 60), _bucket(2, 50)]),
        isFalse,
      );
    });

    test('daftar kosong ditolak', () {
      expect(validateBucketPercentages([]), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // normalizeSubsetAllocation — BR-09
  // ---------------------------------------------------------------------------

  group('normalizeSubsetAllocation — BR-09', () {
    test('subset dua pos dari tiga dinormalisasi ke 100%', () {
      // Total subset = 50 + 20 = 70; normalized: 50/70*100 ≈ 71.43, 20/70*100 ≈ 28.57
      final subset = [_bucket(1, 50), _bucket(3, 20)];
      final result = normalizeSubsetAllocation(subset);

      expect(result.keys, containsAll([1, 3]));
      expect(result[1], closeTo(71.43, 0.01));
      expect(result[3], closeTo(28.57, 0.01));
    });

    test('subset satu pos menjadi 100%', () {
      final result = normalizeSubsetAllocation([_bucket(2, 30)]);
      expect(result[2], closeTo(100.0, 0.01));
    });

    test('subset semua pos mempertahankan persentase asli', () {
      final subset = [_bucket(1, 60), _bucket(2, 40)];
      final result = normalizeSubsetAllocation(subset);
      expect(result[1], closeTo(60.0, 0.01));
      expect(result[2], closeTo(40.0, 0.01));
    });

    test('jumlah normalized percentages selalu 100%', () {
      final subset = [_bucket(1, 50), _bucket(2, 30), _bucket(3, 20)];
      final result = normalizeSubsetAllocation(subset);
      final total = result.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
    });

    test('subset kosong mengembalikan map kosong', () {
      expect(normalizeSubsetAllocation([]), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // allocateIncomeToBuckets — distribusi nominal ke subset pos
  // ---------------------------------------------------------------------------

  group('allocateIncomeToBuckets', () {
    test('income 1 juta dialokasikan ke dua pos sesuai persentase normalized',
        () {
      // Subset: pos A 50%, pos B 20% dari total → normalized A=71.43%, B=28.57%
      final subset = [_bucket(1, 50), _bucket(2, 20)];
      final amount = 1000000.0;
      final allocations = allocateIncomeToBuckets(amount, subset);

      // Jumlah alokasi harus sama dengan income
      final total = allocations.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(amount, 0.01));

      // Pos A harus mendapat lebih banyak dari pos B
      expect(allocations[1]!, greaterThan(allocations[2]!));
    });

    test('satu pos menerima seluruh income', () {
      final subset = [_bucket(5, 100)];
      final allocations = allocateIncomeToBuckets(500000, subset);
      expect(allocations[5], closeTo(500000, 0.01));
    });

    test('income nol menghasilkan alokasi nol untuk semua pos', () {
      final subset = [_bucket(1, 60), _bucket(2, 40)];
      final allocations = allocateIncomeToBuckets(0, subset);
      expect(allocations.values.every((v) => v == 0.0), isTrue);
    });
  });

  group('bucketsShareSameWallet — FEAT-07', () {
    test('dua bucket dalam wallet yang sama diterima', () {
      expect(
        bucketsShareSameWallet([
          _bucketWithWallet(1, 60, walletId: 1),
          _bucketWithWallet(2, 40, walletId: 1),
        ]),
        isTrue,
      );
    });

    test('bucket lintas wallet ditolak', () {
      expect(
        bucketsShareSameWallet([
          _bucketWithWallet(1, 60, walletId: 1),
          _bucketWithWallet(2, 40, walletId: 2),
        ]),
        isFalse,
      );
    });

    test('subset kosong ditolak', () {
      expect(bucketsShareSameWallet(const []), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // executeBucketTransfer — BR-12: transfer tidak mengubah total saldo
  // Pakai test() bukan testWidgets() karena ini DB-level, bukan UI.
  // ---------------------------------------------------------------------------

  group('executeBucketTransfer — BR-12', () {
    test('transfer tidak mengubah total saldo keseluruhan', () async {
      final db = DatabaseHelper();
      await db.database;

      // Insert dua pos dengan saldo awal
      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Pos A',
        allocationPercentage: 60,
        currentBalance: 100,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Pos B',
        allocationPercentage: 40,
        currentBalance: 50,
        createdDate: _now,
        updatedDate: _now,
      ));

      final totalBefore = 150.0;

      // gap: DatabaseHelper.executeBucketTransfer belum ada — Task 5.2
      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 30,
        transferDate: _now,
      );

      final buckets = await db.getFinancialBuckets();
      final totalAfter = buckets.fold(0.0, (s, b) => s + b.currentBalance);

      expect(totalAfter, closeTo(totalBefore, 0.01));
    });

    test('saldo pos sumber berkurang dan pos tujuan bertambah', () async {
      final db = DatabaseHelper();
      await db.database;

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Sumber',
        allocationPercentage: 70,
        currentBalance: 200,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tujuan',
        allocationPercentage: 30,
        currentBalance: 100,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 50,
        transferDate: _now,
      );

      final buckets = await db.getFinancialBuckets();
      final a = buckets.firstWhere((b) => b.id == idA);
      final b = buckets.firstWhere((b) => b.id == idB);

      expect(a.currentBalance, closeTo(150, 0.01));
      expect(b.currentBalance, closeTo(150, 0.01));
    });

    test('transfer dicatat di tabel bucket_transfers', () async {
      final db = DatabaseHelper();
      await db.database;

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'A',
        allocationPercentage: 100,
        currentBalance: 500,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'B',
        allocationPercentage: 0,
        currentBalance: 0,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 100,
        transferDate: _now,
      );

      final transfers = await db.getBucketTransfers();
      expect(transfers.length, 1);
      expect(transfers.first.amount, 100.0);
      expect(transfers.first.fromBucketId, idA);
      expect(transfers.first.toBucketId, idB);
    });

    test(
        'transfer lintas dompet mencatat snapshot wallet dan mutasi wallet internal',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final activeWallets = await db.getActiveWallets();
      final cashWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Cash');
      final bankWallet =
          activeWallets.firstWhere((wallet) => wallet.name == 'Bank');

      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 500000,
        category: 'Gaji',
        description: 'Saldo awal Cash',
        date: _now,
        wallet: 'Cash',
        walletId: 1,
        walletNameSnapshot: 'Cash',
      ));
      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 100000,
        category: 'Gaji',
        description: 'Saldo awal Bank',
        date: _now,
        wallet: 'Bank',
        walletId: 2,
        walletNameSnapshot: 'Bank',
      ));

      final idA = await db.insertFinancialBucket(FinancialBucket(
        name: 'Sumber Cash',
        walletId: cashWallet.id,
        allocationPercentage: 100,
        currentBalance: 500000,
        createdDate: _now,
        updatedDate: _now,
      ));
      final idB = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tujuan Bank',
        walletId: bankWallet.id,
        allocationPercentage: 100,
        currentBalance: 100000,
        createdDate: _now,
        updatedDate: _now,
      ));

      await db.executeBucketTransfer(
        fromBucketId: idA,
        toBucketId: idB,
        amount: 100000,
        transferDate: _now,
      );

      final transfers = await db.getBucketTransfers();
      final txs = await db.getTransactions();
      final cashBalance = calculateBalanceForWallet(
        txs,
        selectedWallet: 'Cash',
      );
      final bankBalance = calculateBalanceForWallet(
        txs,
        selectedWallet: 'Bank',
      );

      expect(transfers.single.fromWalletIdSnapshot, cashWallet.id);
      expect(transfers.single.toWalletIdSnapshot, bankWallet.id);
      expect(cashBalance, closeTo(400000, 0.01));
      expect(bankBalance, closeTo(200000, 0.01));
    });
  });
}
