// ignore_for_file: depend_on_referenced_packages

// Suite regresi lintas-fitur Phase 2–6.
// Setiap test di sini membuktikan integrasi antara minimal dua domain fitur.
// Test per-domain sudah ada di test files masing-masing; file ini hanya
// mencakup skenario yang bisa patah ketika fitur baru bertemu flow lama.

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/debts/models/debt_models.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';

import 'test_support/db_test_harness.dart';

void main() {
  setUpAll(() async {
    await initializeSharedTestDatabase();
  });

  setUp(() async {
    await resetSharedTestDatabase();
  });

  tearDownAll(() async {
    await disposeSharedTestDatabase();
  });

  final now = DateTime(2026);

  // ---------------------------------------------------------------------------
  // Regresi 1: Histori transaksi tetap terbaca setelah dompet diarsipkan
  // Phase 4 (wallet) × Phase 2 (walletNameSnapshot)
  // ---------------------------------------------------------------------------

  group('R1 — histori transaksi terbaca setelah wallet diarsipkan', () {
    test('walletNameSnapshot tidak hilang setelah wallet diarsipkan', () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Regresi',
        createdDate: now,
        updatedDate: now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 75000.0,
        'category': 'Makanan',
        'description': 'Makan siang',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Dompet Regresi',
        'walletId': walletId,
        'walletNameSnapshot': 'Dompet Regresi',
        'affectsBalance': 1,
      });

      await db.archiveWallet(walletId);

      final rows = await rawDb
          .query('transactions', where: 'walletId = ?', whereArgs: [walletId]);
      expect(rows.first['walletNameSnapshot'], 'Dompet Regresi',
          reason: 'Snapshot harus tetap ada setelah dompet diarsipkan');

      final activeWallets = await db.getActiveWallets();
      expect(activeWallets.any((w) => w.name == 'Dompet Regresi'), isFalse,
          reason: 'Dompet yang diarsipkan tidak muncul di daftar aktif');
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 2: Saldo bucket konsisten setelah operasi berurutan
  // Phase 5 (bucket) × Phase 6 (debt payment)
  // ---------------------------------------------------------------------------

  group('R2 — saldo bucket konsisten setelah income allocation + debt payment',
      () {
    test('total saldo bucket tidak berubah setelah alokasi income', () async {
      final db = DatabaseHelper();
      await db.database;

      final b1 = await db.insertFinancialBucket(FinancialBucket(
        name: 'Tabungan',
        allocationPercentage: 60,
        currentBalance: 0,
        createdDate: now,
        updatedDate: now,
      ));
      final b2 = await db.insertFinancialBucket(FinancialBucket(
        name: 'Harian',
        allocationPercentage: 40,
        currentBalance: 0,
        createdDate: now,
        updatedDate: now,
      ));

      final bucket1 =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == b1);
      final bucket2 =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == b2);

      const income = 1000000.0;
      await db.saveIncomeWithAllocations(
        amount: income,
        category: 'Gaji',
        description: 'Gaji Juli',
        date: now,
        walletName: 'Cash',
        subsetBuckets: [bucket1, bucket2],
      );

      final buckets = await db.getFinancialBuckets();
      final totalBalance = buckets.fold(0.0, (s, b) => s + b.currentBalance);
      expect(totalBalance, closeTo(income, 0.01),
          reason:
              'Total saldo bucket harus sama dengan income yang dialokasikan');
    });

    test('debt payment mode=balance + income allocation tetap konsisten',
        () async {
      final db = DatabaseHelper();
      await db.database;

      // Setup: satu bucket dengan saldo awal dari income
      final bucketId = await db.insertFinancialBucket(FinancialBucket(
        name: 'Dana Darurat',
        allocationPercentage: 100,
        currentBalance: 0,
        createdDate: now,
        updatedDate: now,
      ));
      final bucket =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);

      await db.saveIncomeWithAllocations(
        amount: 500000,
        category: 'Gaji',
        description: 'Dana awal cicilan',
        date: now,
        walletName: 'Cash',
        walletId: bucket.walletId,
        subsetBuckets: [bucket],
      );

      // Buat hutang dan catat cicilan yang memengaruhi bucket
      final debtId = await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Rekan',
        principalAmount: 200000,
        remainingAmount: 200000,
        borrowedDate: now,
        recordingMode: 'balance',
        createdDate: now,
        updatedDate: now,
      ));

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 100000,
        paymentDate: now,
        recordingMode: 'balance',
        affectedBucket: bucket,
      );

      // Bucket harus berkurang 100.000 (membayar hutang = uang keluar dari pos)
      final updated =
          (await db.getFinancialBuckets()).firstWhere((b) => b.id == bucketId);
      expect(updated.currentBalance, closeTo(400000, 0.01));

      // Hutang juga harus berkurang
      final updatedDebt = (await db.getDebtById(debtId))!;
      expect(updatedDebt.remainingAmount, closeTo(100000, 0.01));
      expect(updatedDebt.status, 'active');
    });
  });

  // ---------------------------------------------------------------------------
  // Regresi 3: Debt complete lifecycle — Phase 6 end-to-end
  // ---------------------------------------------------------------------------

  group('R3 — debt lifecycle end-to-end', () {
    test('beberapa cicilan berurutan menetapkan status settled dengan benar',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final debtId = await db.insertDebt(Debt(
        type: 'receivable',
        personName: 'Pelanggan',
        principalAmount: 300000,
        remainingAmount: 300000,
        borrowedDate: now,
        recordingMode: 'note',
        createdDate: now,
        updatedDate: now,
      ));

      // Cicilan 1 — masih active
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: now,
          recordingMode: 'note');
      expect((await db.getDebtById(debtId))!.status, 'active');
      expect((await db.getDebtById(debtId))!.remainingAmount,
          closeTo(200000, 0.01));

      // Cicilan 2 — masih active
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: now,
          recordingMode: 'note');
      expect((await db.getDebtById(debtId))!.status, 'active');

      // Cicilan 3 — lunas
      await db.recordDebtPayment(
          debtId: debtId,
          amount: 100000,
          paymentDate: now,
          recordingMode: 'note');
      final settled = (await db.getDebtById(debtId))!;
      expect(settled.status, 'settled');
      expect(settled.remainingAmount, closeTo(0, 0.01));

      final payments = await db.getDebtPaymentsByDebt(debtId);
      expect(payments.length, 3);
    });
  });

  // Catatan: regression widget-level yang berat dipindah ke file domain sempit
  // (`wallet_management_test`, `debt_page_test`, `home_quick_menu_test`,
  // `widget_test`, `pos_keuangan_wallet_binding_test`, dan
  // `transaction_bucket_wallet_message_test`) agar suite ini tetap cepat dan
  // fokus pada integrasi DB-level lintas fitur.
}
