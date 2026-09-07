// Widget-only reset outcome tests; injected handlers never touch the database.
import 'package:cashflow/features/notifications/services/reminder_scheduler.dart';
import 'package:cashflow/features/reset/presentation/reset_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> confirmReset(WidgetTester tester) async {
    final button = find.byKey(const Key('reset_data_cta_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_dialog_confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'committed reset warns and completes even when callback pops route',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Home')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ResetDataPage(
        resetHandler: () async {
          throw ReminderCleanupException(StateError('plugin failed'));
        },
        onResetComplete: () {
          completed++;
          navigator.currentState!.pop();
        },
      ),
    ));
    await tester.pumpAndSettle();
    await confirmReset(tester);

    expect(completed, 1);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('Data sudah direset'), findsOneWidget);
    expect(find.text('Reset gagal. Silakan coba lagi.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed injected reset does not call completion', (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: ResetDataPage(
        resetHandler: () async => throw StateError('DB failed'),
        onResetComplete: () => completed = true,
      ),
    ));
    await confirmReset(tester);
    expect(completed, isFalse);
    expect(find.text('Reset gagal. Silakan coba lagi.'), findsOneWidget);
    expect(find.textContaining('Data sudah direset'), findsNothing);
  });

  testWidgets('successful injected reset replaces the entire reset operation',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ResetDataPage(
        resetHandler: () async => calls.add('reset'),
        onResetComplete: () => calls.add('complete'),
      ),
    ));
    await confirmReset(tester);
    expect(calls, ['reset', 'complete']);
    expect(find.byType(SnackBar), findsNothing);
  });
}
