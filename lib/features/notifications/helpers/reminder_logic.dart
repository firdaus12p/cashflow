enum ReminderDecision {
  none,
  general,
  overdueDebt,
}

DateTime endOfDay(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
    23,
    59,
    59,
    999,
  );
}

bool isDebtOverdueAt(
  DateTime? dueDate,
  DateTime referenceTime,
) {
  if (dueDate == null) return false;
  return endOfDay(dueDate).isBefore(referenceTime);
}

bool isSameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool isOpenedDuringEveningWindow(
  DateTime now,
  DateTime? lastAppOpenedAt, {
  int eveningStartHour = 20,
}) {
  if (lastAppOpenedAt == null) return false;
  if (!isSameCalendarDay(now, lastAppOpenedAt)) return false;
  return lastAppOpenedAt.hour >= eveningStartHour;
}

bool hasFinancialActivityToday(
  DateTime now,
  DateTime? lastFinancialActivityAt,
) {
  if (lastFinancialActivityAt == null) return false;
  return isSameCalendarDay(now, lastFinancialActivityAt);
}

ReminderDecision evaluateReminderDecision({
  required bool isReminderEnabled,
  required DateTime now,
  required int overdueDebtCount,
  DateTime? lastAppOpenedAt,
  DateTime? lastFinancialActivityAt,
  int eveningStartHour = 20,
}) {
  if (!isReminderEnabled) {
    return ReminderDecision.none;
  }

  if (overdueDebtCount > 0) {
    return ReminderDecision.overdueDebt;
  }

  if (isOpenedDuringEveningWindow(
    now,
    lastAppOpenedAt,
    eveningStartHour: eveningStartHour,
  )) {
    return ReminderDecision.none;
  }

  if (hasFinancialActivityToday(now, lastFinancialActivityAt)) {
    return ReminderDecision.none;
  }

  return ReminderDecision.general;
}

int reminderNotificationIdForDate(
  DateTime date,
  ReminderDecision decision,
) {
  final suffix = switch (decision) {
    ReminderDecision.general => 1,
    ReminderDecision.overdueDebt => 2,
    ReminderDecision.none => 0,
  };
  return (date.year * 10000 + date.month * 100 + date.day) * 10 + suffix;
}
