// Macro Templates Screen Placeholder
import 'package:flutter/material.dart';
import '../../models/macro_models.dart';

class MacroTemplatesScreen extends StatefulWidget {
  final Function(MacroTemplate) onTemplateSelected;

  const MacroTemplatesScreen({super.key, required this.onTemplateSelected});

  @override
  State<MacroTemplatesScreen> createState() => _MacroTemplatesScreenState();
}

class _MacroTemplatesScreenState extends State<MacroTemplatesScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Macro Templates Coming Soon'));
  }
}
