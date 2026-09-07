import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_payload.dart';

abstract interface class ReminderNotificationService {
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationPayload payload,
  });

  Future<void> cancelAllPendingReminders();
}

class LocalNotificationService implements ReminderNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationPayload> _payloadController =
      StreamController<NotificationPayload>.broadcast();

  bool _isInitialized = false;

  bool get _supportsScheduledNotifications {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Stream<NotificationPayload> get payloadStream => _payloadController.stream;

  bool get supportsScheduledNotifications => _supportsScheduledNotifications;

  Future<NotificationPayload?> initialize() async {
    if (!_supportsScheduledNotifications) return null;

    if (_isInitialized) {
      return _launchPayloadFromPlugin();
    }

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Buka cashflow'),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _isInitialized = true;
    return _launchPayloadFromPlugin();
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } on Exception {
      tz.setLocalLocation(tz.local);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = NotificationPayload.decode(response.payload);
    if (payload == null) return;
    _payloadController.add(payload);
  }

  Future<NotificationPayload?> _launchPayloadFromPlugin() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    return NotificationPayload.decode(details?.notificationResponse?.payload);
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (!_supportsScheduledNotifications) return true;

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final macImplementation = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();

    var granted = true;

    final androidGranted =
        await androidImplementation?.requestNotificationsPermission();
    if (androidGranted != null) {
      granted = granted && androidGranted;
    }

    final iosGranted = await iosImplementation?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    if (iosGranted != null) {
      granted = granted && iosGranted;
    }

    final macGranted = await macImplementation?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    if (macGranted != null) {
      granted = granted && macGranted;
    }

    return granted;
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    if (!_supportsScheduledNotifications) return;

    final scheduledDate = tz.TZDateTime.from(when, tz.local);
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'cashflow_reminder_channel',
        'Pengingat Cashflow',
        channelDescription: 'Reminder pencatatan keuangan dan hutang overdue',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload.encode(),
    );
  }

  Future<void> cancelReminder(int id) async {
    if (!_supportsScheduledNotifications) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAllPendingReminders() async {
    if (!_supportsScheduledNotifications) return;
    await _plugin.cancelAllPendingNotifications();
  }

  Future<List<PendingNotificationRequest>> pendingRequests() {
    if (!_supportsScheduledNotifications) {
      return Future.value(const []);
    }
    return _plugin.pendingNotificationRequests();
  }
}
