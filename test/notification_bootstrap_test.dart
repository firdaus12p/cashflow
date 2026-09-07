// Bootstrap and platform guards without native plugins or SQLite.
import 'package:cashflow/features/notifications/models/notification_payload.dart';
import 'package:cashflow/features/notifications/services/local_notification_service.dart';
import 'package:cashflow/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('optional notification plugin failure still runs the app', () async {
    for (final error in [
      MissingPluginException('not registered'),
      PlatformException(code: 'initialization_failed'),
      StateError('plugin failed'),
    ]) {
      Widget? app;
      await bootstrapApp(
        initializeNotifications: () async => throw error,
        appRunner: (widget) => app = widget,
      );
      expect(app, isA<CashflowApp>());
      final home = (app! as CashflowApp).home as MainScreen;
      expect(home.initialNotificationPayload, isNull);
    }
  });

  test('successful initialization preserves launch notification payload',
      () async {
    const payload = NotificationPayload(target: NotificationRouteTarget.debts);
    Widget? app;
    await bootstrapApp(
      initializeNotifications: () async => payload,
      appRunner: (widget) => app = widget,
    );
    final home = (app! as CashflowApp).home as MainScreen;
    expect(home.initialNotificationPayload, same(payload));
  });

  test(
      'unconfigured platforms skip plugin calls and keep broadcast stream alive',
      () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = LocalNotificationService.instance;
    var streamClosed = false;
    final first =
        service.payloadStream.listen((_) {}, onDone: () => streamClosed = true);
    await first.cancel();
    final second =
        service.payloadStream.listen((_) {}, onDone: () => streamClosed = true);
    addTearDown(second.cancel);

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(service.supportsScheduledNotifications, isFalse);
      expect(await service.initialize(), isNull);
      await service.cancelAllPendingReminders();
      expect(await service.pendingRequests(), isEmpty);
    }
    expect(streamClosed, isFalse);
  });
}
