import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import 'buddy_code_editor_screen.dart';

class EditorSelector extends StatelessWidget {
  final dynamic projectFlow;

  const EditorSelector({super.key, this.projectFlow});

  @override
  Widget build(BuildContext context) {
    // Convert projectFlow to ProjectModel if needed
    final ProjectModel targetProject = _convertFlowToProject();

    if (Platform.isLinux) {
      // Linux: Try to open Code-OSS, fallback to Buddy Editor
      return FutureBuilder<bool>(
        future: _tryLaunchCodeOSS(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen(context, 'Code-OSS');
          } else if (snapshot.hasData && snapshot.data == true) {
            return _buildCodeOSSLaunchScreen(context, 'Code-OSS');
          } else {
            // Fallback to Buddy Editor if Code-OSS not available
            return BuddyCodeEditorScreen(project: targetProject);
          }
        },
      );
    } else if (Platform.isWindows) {
      // Windows: Try to open VS Code, fallback to Buddy Editor
      return FutureBuilder<bool>(
        future: _tryLaunchVSCode(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen(context, 'VS Code');
          } else if (snapshot.hasData && snapshot.data == true) {
            return _buildCodeOSSLaunchScreen(context, 'VS Code');
          } else {
            // Fallback to Buddy Editor if VS Code not available
            return BuddyCodeEditorScreen(project: targetProject);
          }
        },
      );
    } else {
      // Mobile platforms: directly show Buddy Editor
      return BuddyCodeEditorScreen(project: targetProject);
    }
  }

  ProjectModel _convertFlowToProject() {
    if (projectFlow != null) {
      return ProjectModel(
        name: projectFlow!.title ?? 'Project',
        path: '/tmp/buddy_projects/${projectFlow!.title ?? 'untitled'}',
        projectType: 'general',
      );
    }

    return ProjectModel(
      name: 'Untitled Project',
      path: '/tmp/buddy_projects/untitled',
      projectType: 'general',
    );
  }

  Future<bool> _tryLaunchCodeOSS() async {
    try {
      // Try different Code-OSS command variations
      List<String> codeOSSCommands = ['code-oss', 'codium', 'code'];

      for (String command in codeOSSCommands) {
        try {
          await Process.start(command, [
            '--new-window',
          ], mode: ProcessStartMode.detached);
          print('Successfully launched $command');
          return true; // Return true if successful
        } catch (e) {
          print('Failed to launch $command: $e');
          continue; // Try next command
        }
      }

      return false; // Return false if all commands fail
    } catch (e) {
      print('Failed to launch any code editor: $e');
      return false;
    }
  }

  Future<bool> _tryLaunchVSCode() async {
    try {
      // Try different VS Code command variations
      List<String> vscodeCommands = ['code', 'code-insiders', 'code-oss'];

      for (String command in vscodeCommands) {
        try {
          await Process.start(command, [
            '--new-window',
          ], mode: ProcessStartMode.detached);
          print('Successfully launched $command');
          return true; // Return true if successful
        } catch (e) {
          print('Failed to launch $command: $e');
          continue; // Try next command
        }
      }

      return false; // Return false if all commands fail
    } catch (e) {
      print('Failed to launch any code editor: $e');
      return false;
    }
  }

  Widget _buildLoadingScreen(BuildContext context, String editorName) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Launching $editorName'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Launching external editor...',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeOSSLaunchScreen(BuildContext context, String editorName) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$editorName Launched'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.launch, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '$editorName has been launched!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'A new empty window should have opened.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
