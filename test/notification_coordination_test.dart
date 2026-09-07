// Service-level regressions using fakes, without SQLite or platform plugins.
import 'dart:async';

import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/debts/models/debt_models.dart';
import 'package:cashflow/features/notifications/models/notification_payload.dart';
import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/features/notifications/services/local_notification_service.dart';
import 'package:cashflow/features/notifications/services/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class _Database extends Fake implements DatabaseHelper {
  bool enabled = true;
  int reads = 0;
  int resets = 0;
  Object? resetError;
  List<Debt> debts = [];

  @override
  Future<ReminderPreferences> getReminderPreferences() async {
    reads++;
    return ReminderPreferences(isEnabled: enabled);
  }

  @override
  Future<List<Debt>> getDebts() async => debts;

  @override
  Future<void> resetAllData() async {
    if (resetError != null) throw resetError!;
    resets++;
    enabled = false;
    debts = [];
  }
}

class _Notifications extends Fake implements ReminderNotificationService {
  final started = Completer<void>();
  Completer<void>? release;
  bool failCancellation = false;
  final pending = <({DateTime when, NotificationRouteTarget target})>[];

  @override
  Future<void> cancelAllPendingReminders() async {
    if (failCancellation) throw StateError('cleanup failed');
    pending.clear();
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    if (!started.isCompleted) {
      started.complete();
      await release?.future;
    }
    pending.add((when: when, target: payload.target));
  }
}

void main() {
  final now = DateTime(2026, 9, 5, 19);

  test('latest disable wins across scheduler instances and queued snapshots',
      () async {
    final db = _Database();
    final notifications = _Notifications()..release = Completer<void>();
    ReminderScheduler scheduler() => ReminderScheduler(
          databaseHelper: db,
          notificationService: notifications,
        );

    final old = scheduler().rescheduleForTonight(now: now);
    await notifications.started.future;
    final queued = scheduler().rescheduleForTonight(now: now);
    expect(db.reads, 1);
    db.enabled = false;
    final disabled = scheduler().rescheduleForTonight(now: now);
    notifications.release!.complete();
    await Future.wait([old, queued, disabled]);

    expect(db.reads, 3);
    expect(notifications.pending, isEmpty);
  });

  test('reset and cleanup cannot be overtaken by old scheduling work',
      () async {
    final db = _Database();
    final notifications = _Notifications()..release = Completer<void>();
    ReminderScheduler scheduler() => ReminderScheduler(
          databaseHelper: db,
          notificationService: notifications,
        );

    final old = scheduler().rescheduleForTonight(now: now);
    await notifications.started.future;
    final queued = scheduler().rescheduleForTonight(now: now);
    final reset = scheduler().resetAllData();
    final afterReset = scheduler().rescheduleForTonight(now: now);
    expect(db.resets, 0);
    notifications.release!.complete();
    await Future.wait([old, queued, reset, afterReset]);

    expect(db.resets, 1);
    expect(db.enabled, isFalse);
    expect(notifications.pending, isEmpty);
  });

  test('cleanup failure preserves reset commit and queue recovers', () async {
    final db = _Database();
    final notifications = _Notifications();
    final scheduler = ReminderScheduler(
      databaseHelper: db,
      notificationService: notifications,
    );
    await scheduler.rescheduleForTonight(now: now);
    notifications.failCancellation = true;
    await expectLater(
      scheduler.resetAllData(),
      throwsA(isA<ReminderCleanupException>()),
    );
    expect(db.resets, 1);
    expect(db.enabled, isFalse);
    notifications.failCancellation = false;
    await ReminderScheduler(
            databaseHelper: db, notificationService: notifications)
        .rescheduleForTonight(now: now);
    expect(notifications.pending, isEmpty);
  });

  test('database failure is not classified as notification cleanup failure',
      () async {
    final error = StateError('DB failed');
    final db = _Database()..resetError = error;
    final notifications = _Notifications();
    final scheduler = ReminderScheduler(
      databaseHelper: db,
      notificationService: notifications,
    );
    await scheduler.rescheduleForTonight(now: now);
    await expectLater(scheduler.resetAllData(), throwsA(same(error)));
    expect(db.resets, 0);
    expect(notifications.pending, isNotEmpty);
    await scheduler.rescheduleForTonight(now: now);
  });

  test('debt due today becomes overdue only on the following day', () async {
    final db = _Database()
      ..debts = [
        Debt(
          type: 'debt',
          personName: 'Test',
          principalAmount: 100,
          remainingAmount: 100,
          borrowedDate: now,
          dueDate: now,
          recordingMode: 'note',
          status: 'active',
          createdDate: now,
          updatedDate: now,
        ),
      ];
    final notifications = _Notifications();
    await ReminderScheduler(
            databaseHelper: db, notificationService: notifications)
        .rescheduleForTonight(now: now);
    expect(notifications.pending.first,
        (when: DateTime(2026, 9, 5, 22), target: NotificationRouteTarget.home));
    expect(notifications.pending[1], (
      when: DateTime(2026, 9, 6, 22),
      target: NotificationRouteTarget.debts
    ));
  });
}
