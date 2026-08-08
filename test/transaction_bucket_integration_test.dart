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

  final _now = DateTime(2026);

  Future<FinancialBucket> _freshBucket(
    DatabaseHelper db, {
    required String name,
    required double pct,
    double balance = 0,
  }) async {
    final id = await db.insertFinancialBucket(FinancialBucket(
      name: name,
      allocationPercentage: pct,
      currentBalance: balance,
      createdDate: _now,
      updatedDate: _now,
    ));
    return (await db.getFinancialBuckets()).firstWhere((b) => b.id == id);
  }

  // ---------------------------------------------------------------------------
  // BR-09: alokasi pemasukan ke subset pos → normalisasi + simpan snapshot
  // gap: DatabaseHelper.saveIncomeWithAllocations belum ada — Task 5.4
  // ---------------------------------------------------------------------------

  group('Alokasi pemasukan ke subset pos — BR-09', () {
    test('menyimpan allocation snapshot dengan nominal yang benar', () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await _freshBucket(db, name: 'Tabungan', pct: 50);
      final b2 = await _freshBucket(db, name: 'Belanja', pct: 30);
      final b3 = await _freshBucket(db, name: 'Sedekah', pct: 20);

      // Income 1.000.000 dialokasikan hanya ke b1 dan b3 (subset)
      final subset = [b1, b3];
      const income = 1000000.0;

      // gap: saveIncomeWithAllocations belum ada — ditambahkan di Task 5.4
      final txId = await db.saveIncomeWithAllocations(
        amount: income,
        category: 'Gaji',
        description: 'Gaji Juli',
        date: _now,
        walletName: 'Cash',
        subsetBuckets: subset,
      );

      final allocations = await db.getTransactionBucketAllocations(txId);

      expect(allocations.length, 2);

      final totalAllocated =
          allocations.fold(0.0, (s, a) => s + a.allocatedAmount);
      expect(totalAllocated, closeTo(income, 0.01));

      // Nominal per pos sesuai normalisasi: b1=71.43%, b3=28.57%
      // Nominal per pos sesuai normalisasi: b1=71.43%, b3=28.57%
      final a1 = allocations.firstWhere((a) => a.bucketId == b1.id);
      final a3 = allocations.firstWhere((a) => a.bucketId == b3.id);
      expect(a1.allocatedAmount, closeTo(714285.71, 1.0));
      expect(a3.allocatedAmount, closeTo(285714.29, 1.0));

      // b2 sengaja tidak dimasukkan ke subset — validasi bahwa b2 tidak dapat alokasi
      expect(allocations.any((a) => a.bucketId == b2.id), isFalse,
          reason: 'Pos di luar subset tidak boleh mendapat alokasi');
    });

    test('role semua allocation pemasukan adalah target', () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await _freshBucket(db, name: 'Pos A', pct: 60);
      final b2 = await _freshBucket(db, name: 'Pos B', pct: 40);

      final txId = await db.saveIncomeWithAllocations(
        amount: 500000,
        category: 'Freelance',
        description: 'Project X',
        date: _now,
        walletName: 'Cash',
        subsetBuckets: [b1, b2],
      );

      final allocations = await db.getTransactionBucketAllocations(txId);
      expect(allocations.every((a) => a.role == 'target'), isTrue);
    });

    test('saldo pos bertambah setelah income dialokasikan', () async {
      final db = DatabaseHelper();
      await db.database;

      final b = await _freshBucket(db, name: 'Tabungan', pct: 100, balance: 0);

      await db.saveIncomeWithAllocations(
        amount: 300000,
        category: 'Gaji',
        description: 'Test',
        date: _now,
        walletName: 'Cash',
        subsetBuckets: [b],
      );

      final updated = await db.getFinancialBuckets();
      final updatedB = updated.firstWhere((x) => x.id == b.id);
      expect(updatedB.currentBalance, closeTo(300000, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // BR-10: pengeluaran memengaruhi saldo → wajib satu pos sumber
  // gap: DatabaseHelper.saveExpenseWithSource belum ada — Task 5.4
  // ---------------------------------------------------------------------------

  group('Pengeluaran dengan pos sumber — BR-10', () {
    test('pengeluaran dengan satu pos sumber disimpan sukses', () async {
      final db = DatabaseHelper();
      await db.database;

      final b =
          await _freshBucket(db, name: 'Belanja', pct: 100, balance: 500000);

      final txId = await db.saveExpenseWithSource(
        amount: 100000,
        category: 'Makanan',
        description: 'Makan siang',
        date: _now,
        walletName: 'Cash',
        sourceBucket: b,
      );

      expect(txId, isPositive);

      final allocations = await db.getTransactionBucketAllocations(txId);
      expect(allocations.length, 1);
      expect(allocations.first.role, 'source');
      expect(allocations.first.bucketId, b.id);
    });

    test('saldo pos berkurang setelah pengeluaran dari pos tersebut', () async {
      final db = DatabaseHelper();
      await db.database;

      final b =
          await _freshBucket(db, name: 'Harian', pct: 100, balance: 200000);

      await db.saveExpenseWithSource(
        amount: 50000,
        category: 'Transport',
        description: 'Ojek',
        date: _now,
        walletName: 'Cash',
        sourceBucket: b,
      );

      final updated = await db.getFinancialBuckets();
      final updatedB = updated.firstWhere((x) => x.id == b.id);
      expect(updatedB.currentBalance, closeTo(150000, 0.01));
    });

    test('pengeluaran affectsBalance=false tidak mengubah saldo pos', () async {
      final db = DatabaseHelper();
      await db.database;

      final b =
          await _freshBucket(db, name: 'Cadangan', pct: 100, balance: 100000);

      // Pengeluaran catatan saja (affectsBalance = false) tidak perlu pos sumber
      await db.saveExpenseNoteOnly(
        amount: 75000,
        category: 'Lainnya',
        description: 'Catatan pengeluaran',
        date: _now,
        walletName: 'Cash',
      );

      final updated = await db.getFinancialBuckets();
      final updatedB = updated.firstWhere((x) => x.id == b.id);
      expect(updatedB.currentBalance, closeTo(100000, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // BR-13: saldo wallet dan pos selalu selaras setelah transaksi
  // ---------------------------------------------------------------------------

  group('Sinkronisasi saldo wallet-pos — BR-13', () {
    test(
        'income meningkatkan currentBalance pos sebesar nominal yang dialokasikan',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await _freshBucket(db, name: 'A', pct: 70, balance: 0);
      final b2 = await _freshBucket(db, name: 'B', pct: 30, balance: 0);

      await db.saveIncomeWithAllocations(
        amount: 1000000,
        category: 'Gaji',
        description: 'Gaji bulanan',
        date: _now,
        walletName: 'Cash',
        subsetBuckets: [b1, b2],
      );

      final buckets = await db.getFinancialBuckets();
      final updatedB1 = buckets.firstWhere((b) => b.id == b1.id);
      final updatedB2 = buckets.firstWhere((b) => b.id == b2.id);
      final totalBucketBalance =
          updatedB1.currentBalance + updatedB2.currentBalance;

      expect(totalBucketBalance, closeTo(1000000, 0.01));
    });

    test(
        'expense mengurangi currentBalance pos sumber tepat sebesar nominal pengeluaran',
        () async {
      final db = DatabaseHelper();
      await db.database;

      const initialBalance = 500000.0;
      const expenseAmount = 120000.0;
      final b = await _freshBucket(db,
          name: 'Pengeluaran', pct: 100, balance: initialBalance);

      await db.saveExpenseWithSource(
        amount: expenseAmount,
        category: 'Belanja',
        description: 'Belanja mingguan',
        date: _now,
        walletName: 'Cash',
        sourceBucket: b,
      );

      final updated = await db.getFinancialBuckets();
      final updatedB = updated.firstWhere((x) => x.id == b.id);
      expect(
        updatedB.currentBalance,
        closeTo(initialBalance - expenseAmount, 0.01),
      );
    });
  });
}
