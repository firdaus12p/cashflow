enum NotificationRouteTarget {
  home,
  debts,
}

class NotificationPayload {
  const NotificationPayload({required this.target});

  final NotificationRouteTarget target;

  String encode() {
    return switch (target) {
      NotificationRouteTarget.home => 'target=home',
      NotificationRouteTarget.debts => 'target=debts',
    };
  }

  static NotificationPayload? decode(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return null;

    final pairs = rawPayload.split('&');
    final map = <String, String>{};
    for (final pair in pairs) {
      final separatorIndex = pair.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex >= pair.length - 1) continue;
      final key = pair.substring(0, separatorIndex);
      final value = pair.substring(separatorIndex + 1);
      map[key] = value;
    }

    switch (map['target']) {
      case 'home':
        return const NotificationPayload(target: NotificationRouteTarget.home);
      case 'debts':
        return const NotificationPayload(target: NotificationRouteTarget.debts);
      default:
        return null;
    }
  }
}
