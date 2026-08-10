// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:cashflow/main.dart';

// Wallet objects yang dipakai di widget tests tanpa menyentuh DB sama sekali.
// sqflite_ffi menggunakan real isolate — await-nya tidak bisa di-resolve
// dari dalam fake-async Flutter test. Semua DB access di sini hanya ada di
// test() biasa, bukan di testWidgets().
final _now = DateTime(2026);
final _fakeWallets = [
  Wallet(
      id: 1,
      name: 'Cash',
      iconKey: 'cash',
      createdDate: _now,
      updatedDate: _now),
  Wallet(
      id: 2,
      name: 'E-Wallet',
      iconKey: 'e_wallet',
      createdDate: _now,
      updatedDate: _now),
  Wallet(
      id: 3,
      name: 'Bank',
      iconKey: 'bank',
      createdDate: _now,
      updatedDate: _now),
  Wallet(
      id: 4,
      name: 'Tabungan',
      iconKey: 'savings',
      createdDate: _now,
      updatedDate: _now),
];

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
  // CRUD Dompet (database level) — pakai test() bukan testWidgets()
  // ---------------------------------------------------------------------------

  group('CRUD dompet — database level', () {
    test('insertWallet lalu getActiveWallets mengembalikan dompet baru',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      await db.insertWallet(Wallet(
        name: 'Dompet Test',
        createdDate: now,
        updatedDate: now,
      ));

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.name == 'Dompet Test'), isTrue);
    });

    test('archiveWallet membuat dompet tidak muncul di getActiveWallets',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final id = await db.insertWallet(Wallet(
        name: 'Dompet Arsip',
        createdDate: now,
        updatedDate: now,
      ));

      await db.archiveWallet(id);

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.name == 'Dompet Arsip'), isFalse);

      final all = await db.getWallets();
      expect(all.any((w) => w.name == 'Dompet Arsip'), isTrue);
    });

    test('getActiveWallets tidak termasuk wallet yang isArchived=1', () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      await db.insertWallet(
          Wallet(name: 'W Aktif', createdDate: now, updatedDate: now));
      final id2 = await db.insertWallet(
          Wallet(name: 'W Arsip', createdDate: now, updatedDate: now));
      await db.archiveWallet(id2);

      final actives = await db.getActiveWallets();
      final names = actives.map((w) => w.name).toList();
      expect(names, contains('W Aktif'));
      expect(names, isNot(contains('W Arsip')));
    });

    test('walletNameSnapshot tetap terbaca setelah dompet diarsipkan',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Historis',
        createdDate: now,
        updatedDate: now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 50000.0,
        'category': 'Makanan',
        'description': 'Test',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Dompet Historis',
        'walletId': walletId,
        'walletNameSnapshot': 'Dompet Historis',
        'affectsBalance': 1,
      });

      await db.archiveWallet(walletId);

      final rows = await rawDb.query(
        'transactions',
        where: 'walletId = ?',
        whereArgs: [walletId],
      );
      expect(rows.first['walletNameSnapshot'], 'Dompet Historis');
    });

    test('seed wallets tersedia setelah fresh install', () async {
      final db = DatabaseHelper();
      await db.database;

      final actives = await db.getActiveWallets();
      final names = actives.map((w) => w.name).toList();
      expect(names, containsAll(['Cash', 'E-Wallet', 'Bank', 'Tabungan']));
    });

    test('updateWallet menyimpan perubahan nama', () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final id = await db.insertWallet(
          Wallet(name: 'Nama Lama', createdDate: now, updatedDate: now));

      final wallets = await db.getWallets();
      final wallet = wallets.firstWhere((w) => w.id == id);
      await db.updateWallet(Wallet(
        id: wallet.id,
        name: 'Nama Baru',
        createdDate: wallet.createdDate,
        updatedDate: DateTime.now(),
      ));

      final updated = await db.getWallets();
      expect(updated.any((w) => w.name == 'Nama Baru'), isTrue);
      expect(updated.any((w) => w.name == 'Nama Lama'), isFalse);
    });

    test(
        'updateWallet membackfill walletId untuk transaksi legacy sebelum rename',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(
          Wallet(name: 'Nama Lama', createdDate: now, updatedDate: now));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 45000.0,
        'category': 'Makanan',
        'description': 'Legacy transaksi',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Nama Lama',
        'walletNameSnapshot': '',
        'affectsBalance': 1,
      });

      await db.updateWallet(Wallet(
        id: walletId,
        name: 'Nama Baru',
        createdDate: now,
        updatedDate: now,
      ));

      final rows = await rawDb.query('transactions');
      expect(rows.single['walletId'], walletId);
      expect(rows.single['walletNameSnapshot'], 'Nama Lama');
      expect(rows.single['wallet'], 'Nama Lama');
    });

    test('getActiveWallets setelah archive tidak mengandung wallet tersebut',
        () async {
      final db = DatabaseHelper();
      await db.database;
      final wallets = await db.getActiveWallets();
      final eWallet = wallets.firstWhere((w) => w.name == 'E-Wallet');
      await db.archiveWallet(eWallet.id!);

      final actives = await db.getActiveWallets();
      expect(actives.any((w) => w.name == 'E-Wallet'), isFalse);
    });

    test('getWalletReferenceCount menghitung transaksi legacy tanpa walletId',
        () async {
      final db = DatabaseHelper();
      final rawDb = await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Legacy Wallet',
        createdDate: now,
        updatedDate: now,
      ));

      await rawDb.insert('transactions', {
        'type': 'expense',
        'amount': 25000.0,
        'category': 'Makanan',
        'description': 'Legacy transaksi',
        'date': now.millisecondsSinceEpoch,
        'wallet': 'Legacy Wallet',
        'walletNameSnapshot': 'Legacy Wallet',
        'affectsBalance': 1,
      });

      final wallet =
          (await db.getWallets()).firstWhere((w) => w.id == walletId);
      final referenceCount = await db.getWalletReferenceCount(wallet);
      expect(referenceCount, 1);
    });

    test('deleteWallet mengarsipkan dompet bila masih direferensikan debt',
        () async {
      final db = DatabaseHelper();
      await db.database;

      final now = DateTime.now();
      final walletId = await db.insertWallet(Wallet(
        name: 'Dompet Debt',
        createdDate: now,
        updatedDate: now,
      ));

      await db.insertDebt(Debt(
        type: 'debt',
        personName: 'Budi',
        principalAmount: 150000,
        remainingAmount: 150000,
        borrowedDate: now,
        recordingMode: 'balance',
        walletId: walletId,
        createdDate: now,
        updatedDate: now,
      ));

      await db.deleteWallet(walletId);

      final allWallets = await db.getWallets();
      final storedWallet = allWallets.firstWhere((w) => w.id == walletId);
      final activeWallets = await db.getActiveWallets();
      expect(storedWallet.isArchived, isTrue);
      expect(activeWallets.any((w) => w.id == walletId), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // DompetPage UI — pure Dart objects, zero DB calls di dalam testWidgets
  // ---------------------------------------------------------------------------

  group('DompetPage — tampilan dan interaksi', () {
    testWidgets('DompetPage menampilkan wallet_list ketika ada data',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_list')), findsOneWidget);
    });

    testWidgets('DompetPage menampilkan nama wallet', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);
    });

    testWidgets('DompetPage punya tombol tambah dompet (FAB)', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dompet_fab')), findsOneWidget);
    });

    testWidgets('DompetPage punya tombol edit untuk setiap wallet',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_edit_btn')), findsWidgets);
    });

    testWidgets('form tambah dompet muncul setelah tap FAB', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dompet_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
      expect(find.byKey(const Key('wallet_save_btn')), findsOneWidget);
      expect(find.byKey(const Key('wallet_icon_cash')), findsOneWidget);
    });

    testWidgets('form edit dompet muncul setelah tap tombol edit',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wallet_edit_btn')).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Dompet'), findsOneWidget);
      expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
    });

    testWidgets('DompetPage merender ikon dari iconKey tersimpan',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.payments_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone_android_outlined), findsWidgets);
    });

    testWidgets('DompetPage menampilkan empty state bila tidak ada wallet',
        (tester) async {
      await tester
          .pumpWidget(const MaterialApp(home: DompetPage(initialWallets: [])));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada dompet'), findsOneWidget);
      expect(find.byKey(const Key('wallet_list')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // BR-04 — warning flow arsip dompet berhistori
  // transactionCountForWallet diinjek agar tidak ada DB call di fake-async.
  // ---------------------------------------------------------------------------

  group('BR-04 — warning flow arsip dompet berhistori', () {
    testWidgets('tombol arsip tersedia untuk setiap wallet', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: DompetPage(initialWallets: _fakeWallets)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_archive_btn')), findsWidgets);
    });

    testWidgets('arsip dompet berhistori menampilkan warning dialog',
        (tester) async {
      // Injek: Cash (id=1) punya histori, sisanya tidak
      Future<int> hasHistory(Wallet w) => Future.value(w.id == 1 ? 1 : 0);

      await tester.pumpWidget(MaterialApp(
        home: DompetPage(
          initialWallets: _fakeWallets,
          transactionCountForWallet: hasHistory,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap tombol arsip Cash (item pertama)
      await tester.tap(find.byKey(const Key('wallet_archive_btn')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wallet_archive_warning')), findsOneWidget);
    });

    testWidgets('arsip dompet tanpa histori tidak menampilkan warning',
        (tester) async {
      // Semua wallet dianggap tidak punya histori
      Future<int> noHistory(Wallet w) => Future.value(0);

      await tester.pumpWidget(MaterialApp(
        home: DompetPage(
          initialWallets: _fakeWallets,
          transactionCountForWallet: noHistory,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wallet_archive_btn')).first);
      // Tanpa warning, _loadWallets() dipanggil — tapi karena _handleArchive
      // memanggil DatabaseHelper().archiveWallet di production path...
      // tradeoff: kita hanya verifikasi bahwa dialog tidak muncul di initial tap.
      await tester.pump(); // satu frame
      expect(find.byKey(const Key('wallet_archive_warning')), findsNothing);
    });
  });
}
