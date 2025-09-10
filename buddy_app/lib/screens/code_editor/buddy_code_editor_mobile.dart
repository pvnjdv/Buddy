// lib/screens/code_editor/buddy_code_editor_mobile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../../models/file_model.dart';
import '../../models/project_model.dart';
import '../../services/files/file_manager.dart';
import '../../widgets/code_editor/mobile_file_explorer.dart';
import '../../widgets/code_editor/mobile_code_editor.dart';
import '../../widgets/code_editor/mobile_bottom_bar.dart';
import '../../widgets/code_editor/mobile_quick_actions.dart';

class BuddyCodeEditorMobile extends StatefulWidget {
  const BuddyCodeEditorMobile({super.key});

  @override
  State<BuddyCodeEditorMobile> createState() => _BuddyCodeEditorMobileState();
}

class _BuddyCodeEditorMobileState extends State<BuddyCodeEditorMobile>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _fileTabController;
  late AnimationController _menuAnimationController;

  final FileManager _fileManager = FileManager();

  // Current state
  ProjectModel? _currentProject;
  final List<FileModel> _openFiles = [];
  int _activeFileIndex = 0;
  bool _isFileExplorerVisible = true;
  bool _isMenuOpen = false;
  String _currentWorkingDirectory = '';

  // Search and commands
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  bool _isSearchActive = false;
  bool _isCommandPaletteOpen = false;

  // Device directories
  late String _documentsPath;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeDeviceDirectories();
    _loadState();
  }

  void _initializeControllers() {
    _mainTabController = TabController(length: 4, vsync: this);
    _fileTabController = TabController(length: 1, vsync: this);
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initializeDeviceDirectories() async {
    await _requestPermissions();

    if (Platform.isAndroid) {
      _documentsPath = '/storage/emulated/0/Documents';
    } else if (Platform.isIOS) {
      final directory = Directory.systemTemp.parent;
      _documentsPath = path.join(directory.path, 'Documents');
    }

    // Create default working directory
    _currentWorkingDirectory = path.join(_documentsPath, 'BuddyProjects');
    final workingDir = Directory(_currentWorkingDirectory);
    if (!await workingDir.exists()) {
      await workingDir.create(recursive: true);
    }

    setState(() {});
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [Permission.storage, Permission.manageExternalStorage].request();
    }
  }

  Future<void> _loadState() async {
    // Load saved state from preferences
    try {
      // Implementation for loading state
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _fileTabController.dispose();
    _menuAnimationController.dispose();
    _searchController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_isCommandPaletteOpen) _buildCommandPalette(),
            Expanded(
              child: Row(
                children: [
                  if (_isFileExplorerVisible) ...[
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: MobileFileExplorer(
                        rootPath: _currentWorkingDirectory,
                        onFileSelected: _openFile,
                        onDirectoryChanged: _changeDirectory,
                        onFileCreated: _createFile,
                        onFileDeleted: _deleteFile,
                        onFileRenamed: _renameFile,
                        currentProject: _currentProject,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        if (_openFiles.isNotEmpty) _buildFileTabBar(),
                        Expanded(
                          child: _openFiles.isEmpty
                              ? _buildWelcomeScreen()
                              : MobileCodeEditor(
                                  file: _openFiles[_activeFileIndex],
                                  onContentChanged: _onFileContentChanged,
                                  onSave: _saveFile,
                                  onRun: _runFile,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            MobileBottomBar(
              currentFile: _openFiles.isNotEmpty
                  ? _openFiles[_activeFileIndex]
                  : null,
              onQuickAction: _handleQuickAction,
              onToggleExplorer: _toggleFileExplorer,
              onOpenCommandPalette: _toggleCommandPalette,
            ),
          ],
        ),
      ),
      floatingActionButton: MobileQuickActions(
        onNewFile: () => _createFile('', false),
        onNewFolder: () => _createFile('', true),
        onOpenFolder: _openFolder,
        onSave: _saveCurrentFile,
        onRun: _runCurrentFile,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back to Buddy',
          ),
          Icon(
            Icons.code,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Buddy Editor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isSearchActive) ...[
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search in files...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: _performSearch,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => setState(() => _isSearchActive = false),
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => setState(() => _isSearchActive = true),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _toggleMenu,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandPalette() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                hintText: 'Type command or search...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _executeCommand,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _isCommandPaletteOpen = false),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTabBar() {
    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _openFiles.length,
        itemBuilder: (context, index) {
          final file = _openFiles[index];
          final isActive = index == _activeFileIndex;

          return GestureDetector(
            onTap: () => setState(() => _activeFileIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                border: isActive
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFileIcon(file.path),
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    path.basename(file.path),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (file.isModified) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _closeFile(index),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.code,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Buddy Code Editor',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Mobile-first code editor inspired by Acode',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildWelcomeAction(
                icon: Icons.folder_open,
                label: 'Open Folder',
                onTap: _openFolder,
              ),
              _buildWelcomeAction(
                icon: Icons.note_add,
                label: 'New File',
                onTap: () => _createFile('', false),
              ),
              _buildWelcomeAction(
                icon: Icons.create_new_folder,
                label: 'New Project',
                onTap: _createNewProject,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.dart':
        return Icons.code;
      case '.js':
      case '.ts':
        return Icons.javascript;
      case '.py':
        return Icons.code;
      case '.java':
        return Icons.coffee;
      case '.html':
        return Icons.web;
      case '.css':
        return Icons.css;
      case '.json':
        return Icons.data_object;
      case '.md':
        return Icons.description;
      case '.txt':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // File operations
  Future<void> _openFile(String filePath) async {
    try {
      final file = await _fileManager.loadFile(filePath);
      final existingIndex = _openFiles.indexWhere((f) => f.path == filePath);

      if (existingIndex != -1) {
        setState(() => _activeFileIndex = existingIndex);
        return;
      }

      setState(() {
        _openFiles.add(file);
        _activeFileIndex = _openFiles.length - 1;
        _fileTabController = TabController(
          length: _openFiles.length,
          vsync: this,
        );
      });
    } catch (e) {
      _showError('Failed to open file: $e');
    }
  }

  void _closeFile(int index) {
    if (index < 0 || index >= _openFiles.length) return;

    final file = _openFiles[index];
    if (file.isModified) {
      _showUnsavedChangesDialog(file, () {
        setState(() {
          _openFiles.removeAt(index);
          if (_activeFileIndex >= _openFiles.length) {
            _activeFileIndex = _openFiles.length - 1;
          }
          _fileTabController = TabController(
            length: _openFiles.length,
            vsync: this,
          );
        });
      });
    } else {
      setState(() {
        _openFiles.removeAt(index);
        if (_activeFileIndex >= _openFiles.length) {
          _activeFileIndex = _openFiles.length - 1;
        }
        _fileTabController = TabController(
          length: _openFiles.length,
          vsync: this,
        );
      });
    }
  }

  Future<void> _saveFile(FileModel file) async {
    try {
      await _fileManager.saveFile(file);
      setState(() => file.isModified = false);
      _showSnackBar('File saved successfully');
    } catch (e) {
      _showError('Failed to save file: $e');
    }
  }

  Future<void> _saveCurrentFile() async {
    if (_openFiles.isNotEmpty) {
      await _saveFile(_openFiles[_activeFileIndex]);
    }
  }

  Future<void> _createFile(String parentPath, bool isDirectory) async {
    final fileName = await _showCreateFileDialog(isDirectory);
    if (fileName == null || fileName.isEmpty) return;

    final targetPath = parentPath.isEmpty
        ? path.join(_currentWorkingDirectory, fileName)
        : path.join(parentPath, fileName);

    try {
      if (isDirectory) {
        await Directory(targetPath).create(recursive: true);
      } else {
        await File(targetPath).create(recursive: true);
        await _openFile(targetPath);
      }
      setState(() {}); // Refresh file explorer
    } catch (e) {
      _showError('Failed to create ${isDirectory ? 'directory' : 'file'}: $e');
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final confirmed = await _showConfirmDialog(
      'Delete File',
      'Are you sure you want to delete ${path.basename(filePath)}?',
    );

    if (!confirmed) return;

    try {
      final fileSystemEntity = FileSystemEntity.isDirectorySync(filePath)
          ? Directory(filePath)
          : File(filePath);

      await fileSystemEntity.delete(recursive: true);

      // Remove from open files if it's open
      _openFiles.removeWhere((file) => file.path == filePath);
      setState(() {});
    } catch (e) {
      _showError('Failed to delete file: $e');
    }
  }

  Future<void> _renameFile(String oldPath, String newPath) async {
    try {
      if (FileSystemEntity.isDirectorySync(oldPath)) {
        await Directory(oldPath).rename(newPath);
      } else {
        await File(oldPath).rename(newPath);
      }

      // Update open files
      for (final file in _openFiles) {
        if (file.path == oldPath) {
          file.path = newPath;
        }
      }

      setState(() {});
    } catch (e) {
      _showError('Failed to rename file: $e');
    }
  }

  Future<void> _runFile(FileModel file) async {
    _runCurrentFile();
  }

  Future<void> _runCurrentFile() async {
    if (_openFiles.isEmpty) return;

    final file = _openFiles[_activeFileIndex];
    final ext = path.extension(file.path).toLowerCase();

    // Save file first
    await _saveFile(file);

    String command = '';
    String workingDir = path.dirname(file.path);

    switch (ext) {
      case '.dart':
        command = 'dart run ${path.basename(file.path)}';
        break;
      case '.py':
        command = 'python ${path.basename(file.path)}';
        break;
      case '.js':
        command = 'node ${path.basename(file.path)}';
        break;
      case '.java':
        final baseName = path.basenameWithoutExtension(file.path);
        command = 'javac ${path.basename(file.path)} && java $baseName';
        break;
      case '.cpp':
        final baseName = path.basenameWithoutExtension(file.path);
        command = 'g++ -o $baseName ${path.basename(file.path)} && ./$baseName';
        break;
      case '.c':
        final baseName = path.basenameWithoutExtension(file.path);
        command = 'gcc -o $baseName ${path.basename(file.path)} && ./$baseName';
        break;
      case '.go':
        command = 'go run ${path.basename(file.path)}';
        break;
      default:
        _showError(
          'File type "$ext" not supported for execution.\nSupported: .dart, .py, .js, .java, .cpp, .c, .go',
        );
        return;
    }

    // Show execution dialog
    _showExecutionDialog(command, workingDir, file);
  }

  void _showExecutionDialog(String command, String workingDir, FileModel file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.play_arrow, color: Colors.green),
            SizedBox(width: 8),
            Text('Running ${path.basename(file.path)}'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Working Directory:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      workingDir,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Command:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      command,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('Output:', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      'Code execution in mobile is simulated.\nIn a full implementation, this would show real terminal output.',
                      style: TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _saveAndRunProject();
            },
            icon: Icon(Icons.play_arrow),
            label: Text('Run Project'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndRunProject() async {
    if (_currentProject != null) {
      _showSnackBar('Running project: ${_currentProject!.name}');
      // In a full implementation, this would:
      // 1. Save all modified files
      // 2. Compile/build the project if needed
      // 3. Execute the main file or build script
      // 4. Show output in a dedicated terminal
    } else {
      _showSnackBar('Running individual file...');
    }
  }

  void _changeDirectory(String newPath) {
    setState(() => _currentWorkingDirectory = newPath);
  }

  Future<void> _openFolder() async {
    // Implementation for opening folder picker
    _showSnackBar('Folder picker not implemented yet');
  }

  Future<void> _createNewProject() async {
    final result = await _showCreateProjectDialog();
    if (result == null) return;

    final projectName = result['name']!;
    final projectType = result['type']!;

    final projectPath = path.join(_currentWorkingDirectory, projectName);
    try {
      await Directory(projectPath).create(recursive: true);

      // Create project structure based on type
      await _createProjectStructure(projectPath, projectName, projectType);

      setState(() => _currentWorkingDirectory = projectPath);
      _showSnackBar('$projectType project "$projectName" created successfully');
    } catch (e) {
      _showError('Failed to create project: $e');
    }
  }

  Future<void> _createProjectStructure(
    String projectPath,
    String projectName,
    String projectType,
  ) async {
    switch (projectType) {
      case 'Flutter':
        await _createFlutterProject(projectPath, projectName);
        break;
      case 'Dart':
        await _createDartProject(projectPath, projectName);
        break;
      case 'Python':
        await _createPythonProject(projectPath, projectName);
        break;
      case 'JavaScript':
        await _createJavaScriptProject(projectPath, projectName);
        break;
      case 'Java':
        await _createJavaProject(projectPath, projectName);
        break;
      case 'C++':
        await _createCppProject(projectPath, projectName);
        break;
      default:
        await _createBasicProject(projectPath, projectName);
    }
  }

  Future<void> _createFlutterProject(
    String projectPath,
    String projectName,
  ) async {
    // Create basic Flutter structure
    await Directory(path.join(projectPath, 'lib')).create();
    await Directory(path.join(projectPath, 'test')).create();

    await File(path.join(projectPath, 'pubspec.yaml')).writeAsString('''
name: $projectName
description: A new Flutter project.
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
''');

    await File(path.join(projectPath, 'lib', 'main.dart')).writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$projectName',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: '$projectName Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
''');
  }

  Future<void> _createDartProject(
    String projectPath,
    String projectName,
  ) async {
    await Directory(path.join(projectPath, 'bin')).create();
    await Directory(path.join(projectPath, 'lib')).create();
    await Directory(path.join(projectPath, 'test')).create();

    await File(path.join(projectPath, 'pubspec.yaml')).writeAsString('''
name: $projectName
description: A Dart project.
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:

dev_dependencies:
  lints: ^3.0.0
  test: ^1.21.0
''');

    await File(path.join(projectPath, 'bin', 'main.dart')).writeAsString('''
void main() {
  print('Hello from $projectName!');
}
''');

    await File(
      path.join(projectPath, 'lib', '$projectName.dart'),
    ).writeAsString('''
// TODO: Export any libraries intended for clients of this package.
library $projectName;

export 'src/calculator_base.dart';
''');
  }

  Future<void> _createPythonProject(
    String projectPath,
    String projectName,
  ) async {
    await File(path.join(projectPath, 'main.py')).writeAsString('''
#!/usr/bin/env python3
"""
$projectName - A Python project created with Buddy Editor
"""

def main():
    print("Hello from $projectName!")
    
if __name__ == "__main__":
    main()
''');

    await File(
      path.join(projectPath, 'requirements.txt'),
    ).writeAsString('# Add your dependencies here\n');
    await File(path.join(projectPath, 'README.md')).writeAsString('''
# $projectName

A Python project created with Buddy Editor.

## Installation

```bash
pip install -r requirements.txt
```

## Usage

```bash
python main.py
```
''');
  }

  Future<void> _createJavaScriptProject(
    String projectPath,
    String projectName,
  ) async {
    await File(path.join(projectPath, 'package.json')).writeAsString('''
{
  "name": "$projectName",
  "version": "1.0.0",
  "description": "A JavaScript project created with Buddy Editor",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \\"Error: no test specified\\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "MIT"
}
''');

    await File(path.join(projectPath, 'index.js')).writeAsString('''
/**
 * $projectName - A JavaScript project created with Buddy Editor
 */

function main() {
    console.log("Hello from $projectName!");
}

main();
''');
  }

  Future<void> _createJavaProject(
    String projectPath,
    String projectName,
  ) async {
    final srcPath = path.join(projectPath, 'src');
    await Directory(srcPath).create();

    await File(path.join(srcPath, 'Main.java')).writeAsString('''
/**
 * $projectName - A Java project created with Buddy Editor
 */
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello from $projectName!");
    }
}
''');
  }

  Future<void> _createCppProject(String projectPath, String projectName) async {
    await File(path.join(projectPath, 'main.cpp')).writeAsString('''
/**
 * $projectName - A C++ project created with Buddy Editor
 */
#include <iostream>

int main() {
    std::cout << "Hello from $projectName!" << std::endl;
    return 0;
}
''');

    await File(path.join(projectPath, 'Makefile')).writeAsString('''
CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra
TARGET = $projectName
SOURCE = main.cpp

\$(TARGET): \$(SOURCE)
	\$(CXX) \$(CXXFLAGS) -o \$(TARGET) \$(SOURCE)

clean:
	rm -f \$(TARGET)

.PHONY: clean
''');
  }

  Future<void> _createBasicProject(
    String projectPath,
    String projectName,
  ) async {
    await File(path.join(projectPath, 'main.txt')).writeAsString('''
Welcome to $projectName!

This is a basic project created with Buddy Editor.
You can add any type of files and code here.
''');
  }

  void _onFileContentChanged(FileModel file, String newContent) {
    file.content = newContent;
    file.isModified = true;
    setState(() {});
  }

  void _toggleFileExplorer() {
    setState(() => _isFileExplorerVisible = !_isFileExplorerVisible);
  }

  void _toggleCommandPalette() {
    setState(() => _isCommandPaletteOpen = !_isCommandPaletteOpen);
    if (_isCommandPaletteOpen) {
      _commandController.clear();
    }
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    if (_isMenuOpen) {
      _menuAnimationController.forward();
    } else {
      _menuAnimationController.reverse();
    }
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'save':
        _saveCurrentFile();
        break;
      case 'run':
        _runCurrentFile();
        break;
      case 'search':
        setState(() => _isSearchActive = true);
        break;
      case 'terminal':
        _toggleCommandPalette();
        break;
    }
  }

  void _performSearch(String query) {
    // Implementation for file search
    _showSnackBar('Searching for: $query');
  }

  void _executeCommand(String command) {
    // Implementation for command execution
    _showSnackBar('Executing: $command');
    setState(() => _isCommandPaletteOpen = false);
  }

  // Dialog helpers
  Future<String?> _showCreateFileDialog(bool isDirectory) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Create ${isDirectory ? 'Folder' : 'File'}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '${isDirectory ? 'Folder' : 'File'} name',
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, String>?> _showCreateProjectDialog() async {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        String selectedType = 'Flutter';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Project'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Project name',
                        border: OutlineInputBorder(),
                        labelText: 'Project Name',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Project Type',
                      ),
                      items:
                          [
                                'Flutter',
                                'Dart',
                                'Python',
                                'JavaScript',
                                'Java',
                                'C++',
                                'Basic',
                              ]
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(_getProjectIcon(type), size: 20),
                                      const SizedBox(width: 8),
                                      Text(type),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: nameController.text.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context, {
                            'name': nameController.text,
                            'type': selectedType,
                          });
                        },
                  icon: const Icon(Icons.create),
                  label: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getProjectIcon(String type) {
    switch (type) {
      case 'Flutter':
        return Icons.flutter_dash;
      case 'Dart':
        return Icons.code;
      case 'Python':
        return Icons.psychology;
      case 'JavaScript':
        return Icons.javascript;
      case 'Java':
        return Icons.coffee;
      case 'C++':
        return Icons.memory;
      default:
        return Icons.folder;
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showUnsavedChangesDialog(FileModel file, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
          '${path.basename(file.path)} has unsaved changes. Close anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
