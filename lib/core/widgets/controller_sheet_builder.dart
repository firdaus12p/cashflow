import 'package:flutter/material.dart';

/// Creates controllers only when mounted and owns them through route teardown.
class ControllerSheetBuilder extends StatefulWidget {
  const ControllerSheetBuilder({
    super.key,
    required this.createControllers,
    required this.builder,
  });

  final List<TextEditingController> Function() createControllers;
  final Widget Function(
    BuildContext context,
    StateSetter setState,
    List<TextEditingController> controllers,
  ) builder;

  @override
  State<ControllerSheetBuilder> createState() => _ControllerSheetBuilderState();
}

class _ControllerSheetBuilderState extends State<ControllerSheetBuilder> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.createControllers();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, setState, _controllers);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
