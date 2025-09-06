// lib/screens/code_editor/buddy_code_editor_screen.dart
import 'package:flutter/material.dart';
import '../../models/dock_models.dart';
import '../../models/code_editor_models.dart';
import 'enhanced_buddy_code_editor.dart';

class BuddyCodeEditorScreen extends StatelessWidget {
  final Device? device;
  final CodeProject? project;
  final bool isStandalone;

  const BuddyCodeEditorScreen({
    super.key,
    this.device,
    this.project,
    this.isStandalone = false,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedBuddyCodeEditor(
      device: device,
      project: project,
      isStandalone: isStandalone,
    );
  }
}
