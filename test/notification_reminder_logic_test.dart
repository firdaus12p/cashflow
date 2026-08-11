// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/notifications/helpers/reminder_logic.dart';

void main() {
  group('evaluateReminderDecision', () {
    final now = DateTime(2026, 8, 11, 19);

    test('mengembalikan general bila reminder aktif dan belum ada aktivitas',
        () {
      final decision = evaluateReminderDecision(
        isReminderEnabled: true,
        now: now,
        overdueDebtCount: 0,
      );

      expect(decision, ReminderDecision.general);
    });

    test('mengembalikan none bila app sudah dibuka sejak jam 20:00', () {
      final decision = evaluateReminderDecision(
        isReminderEnabled: true,
        now: DateTime(2026, 8, 11, 21),
        lastAppOpenedAt: DateTime(2026, 8, 11, 20, 30),
        overdueDebtCount: 0,
      );

      expect(decision, ReminderDecision.none);
    });

    test('mengembalikan none bila sudah ada aktivitas finansial hari ini', () {
      final decision = evaluateReminderDecision(
        isReminderEnabled: true,
        now: DateTime(2026, 8, 11, 21, 30),
        lastFinancialActivityAt: DateTime(2026, 8, 11, 21, 15),
        overdueDebtCount: 0,
      );

      expect(decision, ReminderDecision.none);
    });

    test('hutang overdue lebih prioritas daripada skip reminder umum', () {
      final decision = evaluateReminderDecision(
        isReminderEnabled: true,
        now: DateTime(2026, 8, 11, 21, 30),
        lastAppOpenedAt: DateTime(2026, 8, 11, 20, 45),
        lastFinancialActivityAt: DateTime(2026, 8, 11, 21, 10),
        overdueDebtCount: 2,
      );

      expect(decision, ReminderDecision.overdueDebt);
    });

    test('mengembalikan none bila reminder dimatikan', () {
      final decision = evaluateReminderDecision(
        isReminderEnabled: false,
        now: DateTime(2026, 8, 11, 21, 30),
        overdueDebtCount: 3,
      );

      expect(decision, ReminderDecision.none);
    });
  });

  group('reminderNotificationIdForDate', () {
    test('menghasilkan id stabil untuk reminder umum dan hutang overdue', () {
      final date = DateTime(2026, 8, 11);

      expect(
        reminderNotificationIdForDate(date, ReminderDecision.general),
        202608111,
      );
      expect(
        reminderNotificationIdForDate(date, ReminderDecision.overdueDebt),
        202608112,
      );
    });
  });
}
