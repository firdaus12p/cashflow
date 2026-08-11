// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/features/notifications/presentation/pengingat_page.dart';

void main() {
  testWidgets('halaman pengingat menampilkan switch dan penjelasan utama',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PengingatPage(
          initialPreferences: ReminderPreferences(isEnabled: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('page_pengingat')), findsOneWidget);
    expect(find.byKey(const Key('reminder_enabled_switch')), findsOneWidget);
    expect(find.text('22:00 setiap malam'), findsOneWidget);
    expect(find.text('Prioritas hutang overdue'), findsOneWidget);
  });

  testWidgets('halaman pengingat menjelaskan bila reminder tidak didukung',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PengingatPage(
          initialPreferences: ReminderPreferences(isEnabled: false),
          isReminderSupported: false,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Reminder malam belum didukung penuh di platform ini.'),
      findsOneWidget,
    );

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const Key('reminder_enabled_switch')),
    );
    expect(switchTile.onChanged, isNull);
  });
}
