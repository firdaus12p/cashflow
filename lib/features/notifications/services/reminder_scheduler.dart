import '../../../data/database/database_helper.dart';
import '../../debts/models/debt_models.dart';
import '../helpers/reminder_logic.dart';
import '../models/notification_payload.dart';
import 'local_notification_service.dart';

const int _defaultScheduleHorizonDays = 7;

/// The database reset committed, but pending reminders could not be cancelled.
class ReminderCleanupException implements Exception {
  const ReminderCleanupException(this.cause);

  final Object cause;
}

class ReminderScheduler {
  ReminderScheduler({
    DatabaseHelper? databaseHelper,
    ReminderNotificationService? notificationService,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper(),
        _notificationService =
            notificationService ?? LocalNotificationService.instance;

  final DatabaseHelper _databaseHelper;
  final ReminderNotificationService _notificationService;

  // All instances share the OS notification store. Read snapshots only after
  // earlier work finishes, and keep database reset + cancellation indivisible.
  static Future<void> _queue = Future<void>.value();

  static Future<void> _serialize(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> resetAllData() => _serialize(() async {
        await _databaseHelper.resetAllData();
        try {
          await _notificationService.cancelAllPendingReminders();
        } catch (error) {
          throw ReminderCleanupException(error);
        }
      });

  Future<void> rescheduleForTonight({DateTime? now}) =>
      _serialize(() => _rescheduleForTonight(now: now));

  Future<void> _rescheduleForTonight({DateTime? now}) async {
    final referenceTime = now ?? DateTime.now();
    final preferences = await _databaseHelper.getReminderPreferences();

    await _notificationService.cancelAllPendingReminders();
    if (!preferences.isEnabled) {
      return;
    }
    final debts = await _databaseHelper.getDebts();

    for (var offset = 0; offset < _defaultScheduleHorizonDays; offset++) {
      final scheduledTime = DateTime(
        referenceTime.year,
        referenceTime.month,
        referenceTime.day + offset,
        preferences.reminderHour,
      );

      if (scheduledTime.isBefore(referenceTime)) {
        continue;
      }

      final predictedOverdueDebtCount = _predictedOverdueDebtCountAt(
        debts,
        scheduledTime,
      );
      final decision = evaluateReminderDecision(
        isReminderEnabled: preferences.isEnabled,
        now: scheduledTime,
        overdueDebtCount: predictedOverdueDebtCount,
        lastAppOpenedAt: preferences.lastAppOpenedAt,
        lastFinancialActivityAt: preferences.lastFinancialActivityAt,
        eveningStartHour: preferences.eveningStartHour,
      );

      switch (decision) {
        case ReminderDecision.general:
          await _notificationService.scheduleReminder(
            id: reminderNotificationIdForDate(
              scheduledTime,
              ReminderDecision.general,
            ),
            when: scheduledTime,
            title: 'Jangan lupa catat keuangan',
            body:
                'Kalau ada pemasukan atau pengeluaran hari ini, catat dulu sebelum tidur.',
            payload: const NotificationPayload(
              target: NotificationRouteTarget.home,
            ),
          );
          break;
        case ReminderDecision.overdueDebt:
          final body = predictedOverdueDebtCount > 1
              ? 'Ada $predictedOverdueDebtCount hutang yang sudah lewat jatuh tempo. Cek sekarang sebelum tidur.'
              : 'Ada hutang yang sudah lewat jatuh tempo. Cek sekarang sebelum tidur.';
          await _notificationService.scheduleReminder(
            id: reminderNotificationIdForDate(
              scheduledTime,
              ReminderDecision.overdueDebt,
            ),
            when: scheduledTime,
            title: 'Pengingat Hutang',
            body: body,
            payload: const NotificationPayload(
              target: NotificationRouteTarget.debts,
            ),
          );
          break;
        case ReminderDecision.none:
          break;
      }
    }
  }

  int _predictedOverdueDebtCountAt(
    Iterable<Debt> debts,
    DateTime scheduledTime,
  ) {
    return debts.where((debt) {
      final normalizedType = debt.type.trim().toLowerCase();
      return debt.status == 'active' &&
          debt.remainingAmount > 0 &&
          debt.dueDate != null &&
          isDebtOverdueAt(debt.dueDate, scheduledTime) &&
          (normalizedType == 'debt' || normalizedType == 'hutang');
    }).length;
  }
}
