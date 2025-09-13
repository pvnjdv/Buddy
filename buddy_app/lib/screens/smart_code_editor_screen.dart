import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/project_model.dart';
import 'buddy_code_editor/buddy_code_editor_screen.dart';

class SmartCodeEditorScreen extends StatelessWidget {
  final ProjectModel project;

  const SmartCodeEditorScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Platform-specific editor routing
    if (kIsWeb) {
      // Web: Use Monaco Editor (future implementation)
      return _buildWebEditor(context);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: Use Buddy Code Editor (Flutter native)
      return BuddyCodeEditorScreen(project: project);
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop: Try to use local IDE, fallback to Buddy Editor
      return _buildDesktopEditor(context);
    }

    // Fallback: Buddy Code Editor
    return BuddyCodeEditorScreen(project: project);
  }

  Widget _buildWebEditor(BuildContext context) {
    // For web, we'll implement Monaco Editor later
    // For now, show a message and use Buddy Editor
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Web Monaco Editor coming soon! Using Buddy Editor for now.',
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: BuddyCodeEditorScreen(project: project)),
        ],
      ),
    );
  }

  Widget _buildDesktopEditor(BuildContext context) {
    // For desktop, we'll implement local IDE detection later
    // For now, show choice dialog and use Buddy Editor
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isLinux
                        ? 'Code-OSS integration coming soon! Using Buddy Editor for now.'
                        : 'VS Code integration coming soon! Using Buddy Editor for now.',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
                TextButton(
                  onPressed: () => _showInstallInstructions(context),
                  child: Text(
                    'Install ${Platform.isLinux ? 'Code-OSS' : 'VS Code'}',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: BuddyCodeEditorScreen(project: project)),
        ],
      ),
    );
  }

  void _showInstallInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Install ${Platform.isLinux ? 'Code-OSS' : 'VS Code'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To get the full IDE experience, install ${Platform.isLinux ? 'Code-OSS' : 'VS Code'}:',
            ),
            const SizedBox(height: 16),
            if (Platform.isLinux) ...[
              const Text(
                'Ubuntu/Debian:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SelectableText('sudo apt install code'),
              const SizedBox(height: 8),
              const Text(
                'Arch Linux:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SelectableText('sudo pacman -S code'),
              const SizedBox(height: 8),
              const Text(
                'Fedora:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SelectableText('sudo dnf install code'),
            ] else if (Platform.isWindows) ...[
              const Text('Download VS Code from:'),
              const SelectableText('https://code.visualstudio.com/'),
              const SizedBox(height: 8),
              const Text('Or use winget:'),
              const SelectableText('winget install Microsoft.VisualStudioCode'),
            ] else if (Platform.isMacOS) ...[
              const Text('Download VS Code from:'),
              const SelectableText('https://code.visualstudio.com/'),
              const SizedBox(height: 8),
              const Text('Or use Homebrew:'),
              const SelectableText('brew install --cask visual-studio-code'),
            ],
            const SizedBox(height: 16),
            Text(
              'After installation, restart Buddy to enable IDE integration.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
