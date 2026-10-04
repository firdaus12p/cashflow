// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/main.dart';

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

  final now = DateTime(2026, 8, 11, 21, 30);

  Debt buildDebt({
    String type = 'debt',
    String status = 'active',
    DateTime? dueDate,
    double principalAmount = 500000,
    double remainingAmount = 500000,
  }) {
    return Debt(
      type: type,
      personName: 'Budi',
      principalAmount: principalAmount,
      remainingAmount: remainingAmount,
      borrowedDate: DateTime(2026, 8, 1),
      dueDate: dueDate,
      recordingMode: 'note',
      status: status,
      createdDate: DateTime(2026, 8, 1),
      updatedDate: DateTime(2026, 8, 1),
    );
  }

  group('reminder preferences', () {
    test('default preferences memakai jam 22:00 dan threshold 20:00', () async {
      final db = DatabaseHelper();

      final preferences = await db.getReminderPreferences();

      expect(preferences, const ReminderPreferences());
    });

    test('setReminderEnabled menyimpan status reminder', () async {
      final db = DatabaseHelper();

      await db.setReminderEnabled(true);

      final preferences = await db.getReminderPreferences();
      expect(preferences.isEnabled, isTrue);
      expect(preferences.reminderHour, 22);
      expect(preferences.eveningStartHour, 20);
    });

    test('markReminderAppOpenedAt menyimpan waktu buka app malam', () async {
      final db = DatabaseHelper();

      await db.markReminderAppOpenedAt(now);

      final preferences = await db.getReminderPreferences();
      expect(preferences.lastAppOpenedAt, now);
    });
  });

  group('reminder activity and overdue debt query', () {
    test('insertTransaction menandai aktivitas finansial terbaru', () async {
      final db = DatabaseHelper();

      await db.insertTransaction(Transaction(
        type: 'income',
        amount: 75000,
        category: 'Bonus',
        description: 'Bonus malam',
        date: DateTime(2026, 8, 10),
        wallet: 'Cash',
      ));

      final preferences = await db.getReminderPreferences();
      expect(preferences.lastFinancialActivityAt, isNotNull);
    });

    test('getActiveOverdueDebtCount hanya menghitung hutang aktif overdue',
        () async {
      final db = DatabaseHelper();

      await db.insertDebt(
        buildDebt(dueDate: DateTime(2026, 8, 10)),
      );
      await db.insertDebt(
        buildDebt(
          type: 'receivable',
          dueDate: DateTime(2026, 8, 10),
        ),
      );
      await db.insertDebt(
        buildDebt(
          status: 'settled',
          remainingAmount: 0,
          dueDate: DateTime(2026, 8, 9),
        ),
      );
      await db.insertDebt(
        buildDebt(dueDate: DateTime(2026, 8, 12)),
      );

      final overdueCount = await db.getActiveOverdueDebtCount(
        referenceTime: now,
      );

      expect(overdueCount, 1);
    });

    test('getActiveOverdueDebtCount mengikuti unit rupiah untuk sisa pecahan',
        () async {
      final db = DatabaseHelper();

      await db.insertDebt(
        buildDebt(
          dueDate: DateTime(2026, 8, 10),
          remainingAmount: 0.4,
        ),
      );
      await db.insertDebt(
        buildDebt(
          dueDate: DateTime(2026, 8, 10),
          remainingAmount: 0.6,
        ),
      );

      final overdueCount = await db.getActiveOverdueDebtCount(
        referenceTime: now,
      );

      expect(overdueCount, 1);
    });

    test('recordDebtPayment yang melunasi hutang menghentikan status overdue',
        () async {
      final db = DatabaseHelper();

      await db.markFinancialActivity(DateTime(2026, 1, 1));

      final debtId = await db.insertDebt(
        buildDebt(dueDate: DateTime(2026, 8, 10)),
      );

      await db.recordDebtPayment(
        debtId: debtId,
        amount: 500000,
        paymentDate: now,
        recordingMode: 'note',
      );

      final overdueCount = await db.getActiveOverdueDebtCount(
        referenceTime: now,
      );
      final preferences = await db.getReminderPreferences();

      expect(overdueCount, 0);
      expect(preferences.lastFinancialActivityAt, isNotNull);
      expect(
        preferences.lastFinancialActivityAt!.isAfter(DateTime(2026, 1, 1)),
        isTrue,
      );
    });
  });
}
