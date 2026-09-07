// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/debts/models/debt_models.dart';
import 'package:cashflow/features/notifications/models/notification_payload.dart';
import 'package:cashflow/features/notifications/services/local_notification_service.dart';
import 'package:cashflow/features/notifications/services/reminder_scheduler.dart';

import 'test_support/db_test_harness.dart';

typedef _ScheduledReminder = ({
  int id,
  DateTime when,
  String title,
  String body,
  NotificationPayload payload,
});

class _FakeReminderNotificationService implements ReminderNotificationService {
  bool cancelAllCalled = false;
  final List<_ScheduledReminder> scheduledReminders = [];

  @override
  Future<void> cancelAllPendingReminders() async {
    cancelAllCalled = true;
    scheduledReminders.clear();
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    scheduledReminders.add((
      id: id,
      when: when,
      title: title,
      body: body,
      payload: payload,
    ));
  }
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

  Debt buildDebt({
    required DateTime dueDate,
    String type = 'debt',
    String status = 'active',
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

  group('ReminderScheduler', () {
    test('hutang overdue menggantikan reminder umum pada malam yang sama',
        () async {
      final db = DatabaseHelper();
      final notificationService = _FakeReminderNotificationService();
      final scheduler = ReminderScheduler(
        databaseHelper: db,
        notificationService: notificationService,
      );
      final now = DateTime(2026, 8, 11, 19);

      await db.setReminderEnabled(true);
      await db.insertDebt(
        buildDebt(dueDate: DateTime(2026, 8, 10)),
      );

      await scheduler.rescheduleForTonight(now: now);

      expect(notificationService.cancelAllCalled, isTrue);
      expect(notificationService.scheduledReminders, isNotEmpty);
      expect(
        notificationService.scheduledReminders
            .where((reminder) =>
                reminder.payload.target == NotificationRouteTarget.home)
            .isEmpty,
        isTrue,
      );
      expect(
        notificationService.scheduledReminders.every(
          (reminder) =>
              reminder.payload.target == NotificationRouteTarget.debts,
        ),
        isTrue,
      );
      expect(
        notificationService.scheduledReminders.first.when,
        DateTime(2026, 8, 11, 22),
      );
    });

    test('buka app malam ini hanya membatalkan reminder umum malam ini',
        () async {
      final db = DatabaseHelper();
      final notificationService = _FakeReminderNotificationService();
      final scheduler = ReminderScheduler(
        databaseHelper: db,
        notificationService: notificationService,
      );
      final now = DateTime(2026, 8, 11, 21, 30);

      await db.setReminderEnabled(true);
      await db.markReminderAppOpenedAt(DateTime(2026, 8, 11, 20, 45));

      await scheduler.rescheduleForTonight(now: now);

      final generalReminders = notificationService.scheduledReminders
          .where((reminder) =>
              reminder.payload.target == NotificationRouteTarget.home)
          .toList(growable: false);

      expect(generalReminders, isNotEmpty);
      expect(
        generalReminders.any(
          (reminder) =>
              reminder.when.year == 2026 &&
              reminder.when.month == 8 &&
              reminder.when.day == 11,
        ),
        isFalse,
      );
      expect(
        generalReminders.any(
          (reminder) =>
              reminder.when.year == 2026 &&
              reminder.when.month == 8 &&
              reminder.when.day == 12,
        ),
        isTrue,
      );
    });
  });
}
