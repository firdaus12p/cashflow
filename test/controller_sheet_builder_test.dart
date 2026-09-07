import 'package:cashflow/core/widgets/controller_sheet_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackedController extends TextEditingController {
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

void main() {
  testWidgets(
      'focused controller lives through pop and is disposed with subtree',
      (tester) async {
    final controller = _TrackedController();
    var creations = 0;
    var routeCompleted = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
          onPressed: () {
            showModalBottomSheet<void>(
                context: context,
                builder: (_) => ControllerSheetBuilder(
                      createControllers: () {
                        creations++;
                        return [controller];
                      },
                      builder: (context, setState, controllers) =>
                          TextField(controller: controllers.single),
                    )).then((_) => routeCompleted = true);
          },
          child: const Text('Open'));
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Focused');
    expect(tester.testTextInput.isVisible, isTrue);
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pump();
    expect(routeCompleted, isTrue);
    expect(controller.disposeCount, 0);
    controller.text = 'Still mounted during reverse animation';
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.disposeCount, 0);
    await tester.pumpAndSettle();
    expect(creations, 1);
    expect(controller.disposeCount, 1);
    expect(tester.takeException(), isNull);
  });
}
