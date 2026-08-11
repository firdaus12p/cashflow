import '../../../data/database/database_helper.dart';
import '../../debts/models/debt_models.dart';
import '../helpers/reminder_logic.dart';
import '../models/notification_payload.dart';
import 'local_notification_service.dart';

const int _defaultScheduleHorizonDays = 7;
const int _generalReminderNotificationId = 220001;

class ReminderScheduler {
  ReminderScheduler({
    DatabaseHelper? databaseHelper,
    LocalNotificationService? notificationService,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper(),
        _notificationService =
            notificationService ?? LocalNotificationService.instance;

  final DatabaseHelper _databaseHelper;
  final LocalNotificationService _notificationService;

  Future<void> rescheduleForTonight({DateTime? now}) async {
    final referenceTime = now ?? DateTime.now();
    final preferences = await _databaseHelper.getReminderPreferences();
    final debts = await _databaseHelper.getDebts();

    await _notificationService.cancelAllPendingReminders();
    if (!preferences.isEnabled) {
      return;
    }

    final generalReminderTime = _nextGeneralReminderTime(
      referenceTime,
      preferences.reminderHour,
    );
    final todayGeneralDecision = evaluateReminderDecision(
      isReminderEnabled: preferences.isEnabled,
      now: generalReminderTime,
      overdueDebtCount: 0,
      lastAppOpenedAt: preferences.lastAppOpenedAt,
      lastFinancialActivityAt: preferences.lastFinancialActivityAt,
      eveningStartHour: preferences.eveningStartHour,
    );

    if (todayGeneralDecision == ReminderDecision.general) {
      await _notificationService.scheduleDailyReminder(
        id: _generalReminderNotificationId,
        firstOccurrence: generalReminderTime,
        title: 'Jangan lupa catat keuangan',
        body:
            'Kalau ada pemasukan atau pengeluaran hari ini, catat dulu sebelum tidur.',
        payload:
            const NotificationPayload(target: NotificationRouteTarget.home),
      );
    }

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
      final decision = predictedOverdueDebtCount > 0
          ? ReminderDecision.overdueDebt
          : ReminderDecision.none;

      if (decision == ReminderDecision.overdueDebt) {
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
      }
    }
  }

  DateTime _nextGeneralReminderTime(DateTime now, int reminderHour) {
    final todayReminder = DateTime(
      now.year,
      now.month,
      now.day,
      reminderHour,
    );
    if (todayReminder.isAfter(now)) {
      return todayReminder;
    }
    return todayReminder.add(const Duration(days: 1));
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
