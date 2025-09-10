// lib/widgets/code_editor/mobile_quick_actions.dart
import 'package:flutter/material.dart';

class MobileQuickActions extends StatelessWidget {
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;
  final VoidCallback onOpenFolder;
  final VoidCallback onSave;
  final VoidCallback onRun;

  const MobileQuickActions({
    super.key,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onOpenFolder,
    required this.onSave,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: "run",
          onPressed: onRun,
          backgroundColor: Colors.green,
          child: const Icon(Icons.play_arrow, color: Colors.white),
          tooltip: 'Run File',
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "save",
          onPressed: onSave,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.save, color: Colors.white),
          tooltip: 'Save File',
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "newFile",
          onPressed: onNewFile,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          child: const Icon(Icons.note_add, color: Colors.white),
          tooltip: 'New File',
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "newFolder",
          onPressed: onNewFolder,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          child: const Icon(Icons.create_new_folder, color: Colors.white),
          tooltip: 'New Folder',
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "openFolder",
          onPressed: onOpenFolder,
          backgroundColor: Theme.of(context).colorScheme.outline,
          child: const Icon(Icons.folder_open, color: Colors.white),
          tooltip: 'Open Folder',
        ),
      ],
    );
  }
}
