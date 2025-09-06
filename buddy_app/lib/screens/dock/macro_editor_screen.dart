// Macro Editor Screen Placeholder
import 'package:flutter/material.dart';
import '../../models/macro_models.dart';
import '../../models/dock_models.dart' hide DeviceMacro;

class MacroEditorScreen extends StatefulWidget {
  final Device? device;
  final List<Device> devices;
  final DeviceMacro? macro;
  final MacroTemplate? template;

  const MacroEditorScreen({
    super.key,
    this.device,
    required this.devices,
    this.macro,
    this.template,
  });

  @override
  State<MacroEditorScreen> createState() => _MacroEditorScreenState();
}

class _MacroEditorScreenState extends State<MacroEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.macro != null ? 'Edit Macro' : 'Create Macro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Macro Editor Coming Soon')),
    );
  }
}
