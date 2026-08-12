// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/buckets/presentation/pos_keuangan_page.dart';
import 'package:cashflow/features/debts/models/debt_models.dart';
import 'package:cashflow/features/debts/presentation/debt_pages.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:cashflow/features/wallets/presentation/dompet_page.dart';

import 'test_support/db_test_harness.dart';

final _now = DateTime(2026, 8, 12);

final _wallets = [
  Wallet(
    id: 1,
    name: 'Cash',
    iconKey: 'cash',
    createdDate: _now,
    updatedDate: _now,
  ),
];

final _buckets = [
  FinancialBucket(
    id: 1,
    name: 'Dana Darurat',
    iconKey: 'emergency',
    walletId: 1,
    allocationPercentage: 100,
    currentBalance: 250000,
    createdDate: _now,
    updatedDate: _now,
  ),
];

final _debts = [
  Debt(
    id: 1,
    type: 'debt',
    personName: 'Budi',
    principalAmount: 500000,
    remainingAmount: 300000,
    borrowedDate: _now,
    recordingMode: 'note',
    status: 'active',
    createdDate: _now,
    updatedDate: _now,
  ),
];

List<Wallet> _manyWallets() => List.generate(
      12,
      (index) => Wallet(
        id: index + 1,
        name: 'Wallet ${index + 1}',
        iconKey: 'cash',
        createdDate: _now,
        updatedDate: _now,
      ),
    );

List<FinancialBucket> _manyBuckets() => List.generate(
      12,
      (index) => FinancialBucket(
        id: index + 1,
        name: 'Bucket ${index + 1}',
        iconKey: 'cash',
        walletId: 1,
        allocationPercentage: 10,
        currentBalance: (100000 + index).toDouble(),
        createdDate: _now,
        updatedDate: _now,
      ),
    );

List<Debt> _manyDebts() => List.generate(
      12,
      (index) => Debt(
        id: index + 1,
        type: 'debt',
        personName: 'Orang ${index + 1}',
        principalAmount: 500000,
        remainingAmount: 300000,
        borrowedDate: _now,
        recordingMode: 'note',
        status: 'active',
        createdDate: _now,
        updatedDate: _now,
      ),
    );

Future<void> _pumpUi(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _pumpSingleFrameUi(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

Future<void> _pumpUiWithMediaQuery(
  WidgetTester tester, {
  required MediaQueryData mediaQueryData,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: mediaQueryData,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

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

  group('Quick menu pages mirror wishlist CTA pattern', () {
    testWidgets('Dompet tetap menampilkan CTA saat loading awal',
        (tester) async {
      await _pumpSingleFrameUi(
        tester,
        const DompetPage(),
      );

      expect(find.byKey(const Key('dompet_fab')), findsOneWidget);
      expect(find.byKey(const Key('dompet_loading_state')), findsOneWidget);
    });

    testWidgets('Hutang tetap menampilkan CTA saat loading awal',
        (tester) async {
      await _pumpSingleFrameUi(
        tester,
        const HutangPiutangPage(
          initialWallets: [],
          initialBuckets: [],
        ),
      );

      expect(find.byKey(const Key('debt_fab')), findsOneWidget);
      expect(find.byKey(const Key('debt_loading_state')), findsOneWidget);
    });

    testWidgets('Pos keuangan tetap menampilkan CTA saat loading awal',
        (tester) async {
      await _pumpSingleFrameUi(
        tester,
        const PosKeuanganPage(),
      );

      expect(find.byKey(const Key('pos_fab')), findsOneWidget);
      expect(find.byKey(const Key('pos_loading_state')), findsOneWidget);
    });

    testWidgets('Dompet memindahkan CTA tambah ke header tanpa FAB',
        (tester) async {
      await _pumpUi(
        tester,
        DompetPage(initialWallets: _wallets),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Dompet'), findsWidgets);
      expect(find.byKey(const Key('dompet_fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dompet_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Dompet'), findsOneWidget);
    });

    testWidgets('Dompet empty state menyediakan CTA tambah di dalam konten',
        (tester) async {
      await _pumpUi(
        tester,
        const DompetPage(initialWallets: []),
      );

      expect(find.text('Belum ada dompet'), findsOneWidget);
      expect(find.text('+ Tambah Dompet'), findsWidgets);
      expect(find.byKey(const Key('dompet_empty_add_btn')), findsOneWidget);
    });

    testWidgets('Hutang memindahkan CTA tambah ke header tanpa FAB',
        (tester) async {
      await _pumpUi(
        tester,
        HutangPiutangPage(
          initialDebts: _debts,
          initialWallets: _wallets,
          initialBuckets: _buckets,
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Hutang / Piutang'), findsWidgets);
      expect(find.byKey(const Key('debt_fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('debt_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Catat Hutang / Piutang'), findsOneWidget);
    });

    testWidgets('Hutang empty state menyediakan CTA tambah di dalam konten',
        (tester) async {
      await _pumpUi(
        tester,
        HutangPiutangPage(
          initialDebts: const [],
          initialWallets: _wallets,
          initialBuckets: _buckets,
        ),
      );

      expect(find.text('Belum ada hutang/piutang'), findsOneWidget);
      expect(find.byKey(const Key('debt_empty_add_btn')), findsOneWidget);
      expect(find.text('+ Catat Hutang / Piutang'), findsOneWidget);
    });

    testWidgets('Pos keuangan memindahkan CTA tambah ke header tanpa FAB',
        (tester) async {
      await _pumpUi(
        tester,
        PosKeuanganPage(
          initialBuckets: _buckets,
          initialWallets: _wallets,
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Pos Keuangan'), findsWidgets);
      expect(find.byKey(const Key('pos_fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Pos Keuangan'), findsOneWidget);
    });

    testWidgets(
        'Pos keuangan empty state menyediakan CTA tambah di dalam konten',
        (tester) async {
      await _pumpUi(
        tester,
        PosKeuanganPage(
          initialBuckets: const [],
          initialWallets: _wallets,
        ),
      );

      expect(find.text('Belum ada pos keuangan'), findsOneWidget);
      expect(find.byKey(const Key('pos_empty_add_btn')), findsOneWidget);
      expect(find.text('+ Tambah Pos Keuangan'), findsOneWidget);
    });

    testWidgets('Dompet list panjang tetap di atas inset bawah sistem',
        (tester) async {
      const mediaQueryData = MediaQueryData(
        size: Size(400, 560),
        viewPadding: EdgeInsets.only(bottom: 24),
      );

      await _pumpUiWithMediaQuery(
        tester,
        mediaQueryData: mediaQueryData,
        child: DompetPage(initialWallets: _manyWallets()),
      );

      await tester.scrollUntilVisible(
        find.text('Wallet 12'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      final itemRect = tester.getRect(find.text('Wallet 12'));
      expect(
        itemRect.bottom,
        lessThanOrEqualTo(
          mediaQueryData.size.height - mediaQueryData.viewPadding.bottom,
        ),
      );
    });

    testWidgets('Hutang list panjang tetap di atas inset bawah sistem',
        (tester) async {
      const mediaQueryData = MediaQueryData(
        size: Size(400, 560),
        viewPadding: EdgeInsets.only(bottom: 24),
      );

      await _pumpUiWithMediaQuery(
        tester,
        mediaQueryData: mediaQueryData,
        child: HutangPiutangPage(
          initialDebts: _manyDebts(),
          initialWallets: _wallets,
          initialBuckets: _buckets,
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Orang 12'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      final itemRect = tester.getRect(find.text('Orang 12'));
      expect(
        itemRect.bottom,
        lessThanOrEqualTo(
          mediaQueryData.size.height - mediaQueryData.viewPadding.bottom,
        ),
      );
    });

    testWidgets('Pos keuangan list panjang tetap di atas inset bawah sistem',
        (tester) async {
      const mediaQueryData = MediaQueryData(
        size: Size(400, 560),
        viewPadding: EdgeInsets.only(bottom: 24),
      );

      await _pumpUiWithMediaQuery(
        tester,
        mediaQueryData: mediaQueryData,
        child: PosKeuanganPage(
          initialBuckets: _manyBuckets(),
          initialWallets: _wallets,
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Bucket 12'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      final itemRect = tester.getRect(find.text('Bucket 12'));
      expect(
        itemRect.bottom,
        lessThanOrEqualTo(
          mediaQueryData.size.height - mediaQueryData.viewPadding.bottom,
        ),
      );
    });
  });
}
