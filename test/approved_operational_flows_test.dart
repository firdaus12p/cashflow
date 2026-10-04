import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/features/notifications/presentation/pengingat_page.dart';
import 'package:cashflow/features/wallets/presentation/dompet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/db_test_harness.dart';

void main() {
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final db = DatabaseHelper();

  setUpAll(initializeSharedTestDatabase);
  setUp(() async {
    await resetSharedTestDatabase();
    mockTestFontAssets();
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  tearDownAll(disposeSharedTestDatabase);

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showSettings(WidgetTester tester, {bool enabled = true}) async {
    await tester.runAsync(() => db.setReminderEnabled(enabled));
    await tester.pumpWidget(MaterialApp(
      home: PengingatPage(
        initialPreferences: ReminderPreferences(isEnabled: enabled),
        isReminderSupported: true,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, bool enabled) async {
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('reminder_enabled_switch')),
    );
    await tester.runAsync(() async {
      await (Function.apply(tile.onChanged!, [enabled]) as Future<void>);
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
      'OPS01 saved preference stays effective when OS cancellation fails',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'cancel_failed');
    });
    await showSettings(tester);
    await toggle(tester, false);

    expect(await tester.runAsync(db.getReminderPreferences),
        const ReminderPreferences());
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.textContaining('Pengaturan tersimpan, tetapi jadwal'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'OPS01 database failure reloads old preference and skips OS scheduling',
      (tester) async {
    var pluginCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      pluginCalls++;
      return null;
    });
    await showSettings(tester);
    await tester.runAsync(() async {
      await (await db.database).execute('''
        CREATE TRIGGER audit_reject_preference BEFORE INSERT ON app_preferences
        BEGIN SELECT RAISE(ABORT, 'audit write failure'); END
      ''');
    });
    await toggle(tester, false);
    expect(
        (await tester.runAsync(db.getReminderPreferences))!.isEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(pluginCalls, 0);
    expect(find.text('Pengaturan pengingat gagal disimpan. Coba lagi.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OPS01 denied permission preserves preference', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    await showSettings(tester, enabled: false);
    await toggle(tester, true);
    expect(
        (await tester.runAsync(db.getReminderPreferences))!.isEnabled, isFalse);
    expect(find.text('Izin notifikasi belum diberikan.'), findsOneWidget);
  });

  testWidgets(
      'OPS01 successful disable refreshes switch without failure message',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await showSettings(tester);
    await toggle(tester, false);
    expect(
        (await tester.runAsync(db.getReminderPreferences))!.isEnabled, isFalse);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'OPS01 dismissal during post-save callback failure does not use disposed state',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await tester.runAsync(() => db.setReminderEnabled(true));
    await tester.pumpWidget(MaterialApp(
        home: PengingatPage(
      initialPreferences: const ReminderPreferences(isEnabled: true),
      isReminderSupported: true,
      onPreferencesChanged: () async {
        await tester.pumpWidget(const SizedBox.shrink());
        throw StateError('refresh failed after dismissal');
      },
    )));
    await tester.pumpAndSettle();
    await toggle(tester, false);
    expect(
        (await tester.runAsync(db.getReminderPreferences))!.isEnabled, isFalse);
    expect(find.byType(PengingatPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OPS05 explains finite horizon on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showSettings(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('reminder_schedule_horizon')),
      200,
    );
    expect(find.textContaining('6 atau 7 malam'), findsOneWidget);
    expect(find.textContaining('pengingat berhenti setelah malam terakhir'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> showWallets(WidgetTester tester) async {
    final wallets = await tester.runAsync(db.getActiveWallets);
    await tester
        .pumpWidget(MaterialApp(home: DompetPage(initialWallets: wallets)));
    await tester.pumpAndSettle();
  }

  Future<void> saveWallet(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('wallet_name_field')), name);
    await tester.tap(find.byKey(const Key('wallet_save_btn')));
    await settleDatabase(tester);
  }

  testWidgets(
      'OPS03 empty and duplicate wallet names keep form open, corrected name saves',
      (tester) async {
    await showWallets(tester);
    await tester.tap(find.byKey(const Key('dompet_fab')));
    await tester.pumpAndSettle();
    await saveWallet(tester, '   ');
    expect(find.text('Nama dompet wajib diisi.'), findsOneWidget);
    await saveWallet(tester, ' Cash ');
    expect(find.textContaining('Nama dompet sudah dipakai'), findsOneWidget);
    expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
    expect(
        (await tester.runAsync(db.getWallets))!
            .where((w) => w.name == 'Cash')
            .length,
        1);
    await saveWallet(tester, ' Dana Liburan ');
    expect(find.byKey(const Key('wallet_name_field')), findsNothing);
    expect(
        (await tester.runAsync(db.getWallets))!
            .where((w) => w.name == 'Dana Liburan')
            .length,
        1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OPS03 duplicate rename leaves original wallet intact',
      (tester) async {
    await showWallets(tester);
    await tester.tap(find.byKey(const Key('wallet_edit_btn')).first);
    await tester.pumpAndSettle();
    final wallets = (await tester.runAsync(db.getActiveWallets))!;
    await saveWallet(tester, wallets[1].name);
    expect(find.textContaining('Nama dompet sudah dipakai'), findsOneWidget);
    expect((await tester.runAsync(db.getActiveWallets))!.first.name,
        wallets.first.name);
    expect(find.byKey(const Key('wallet_name_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
