class ReminderPreferences {
  const ReminderPreferences({
    this.isEnabled = false,
    this.reminderHour = 22,
    this.eveningStartHour = 20,
    this.lastAppOpenedAt,
    this.lastFinancialActivityAt,
  });

  final bool isEnabled;
  final int reminderHour;
  final int eveningStartHour;
  final DateTime? lastAppOpenedAt;
  final DateTime? lastFinancialActivityAt;

  ReminderPreferences copyWith({
    bool? isEnabled,
    int? reminderHour,
    int? eveningStartHour,
    DateTime? lastAppOpenedAt,
    bool clearLastAppOpenedAt = false,
    DateTime? lastFinancialActivityAt,
    bool clearLastFinancialActivityAt = false,
  }) {
    return ReminderPreferences(
      isEnabled: isEnabled ?? this.isEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      eveningStartHour: eveningStartHour ?? this.eveningStartHour,
      lastAppOpenedAt: clearLastAppOpenedAt
          ? null
          : (lastAppOpenedAt ?? this.lastAppOpenedAt),
      lastFinancialActivityAt: clearLastFinancialActivityAt
          ? null
          : (lastFinancialActivityAt ?? this.lastFinancialActivityAt),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderPreferences &&
        other.isEnabled == isEnabled &&
        other.reminderHour == reminderHour &&
        other.eveningStartHour == eveningStartHour &&
        other.lastAppOpenedAt == lastAppOpenedAt &&
        other.lastFinancialActivityAt == lastFinancialActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        isEnabled,
        reminderHour,
        eveningStartHour,
        lastAppOpenedAt,
        lastFinancialActivityAt,
      );
}
