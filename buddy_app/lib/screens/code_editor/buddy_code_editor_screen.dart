// lib/screens/code_editor/buddy_code_editor_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/dock_models.dart';
import '../../models/code_editor_models.dart';
import '../../services/code_editor_service.dart';
import '../../services/sync_service.dart';
import 'project_templates_screen.dart';

class BuddyCodeEditorScreen extends StatefulWidget {
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
  State<BuddyCodeEditorScreen> createState() => _BuddyCodeEditorScreenState();
}

class _BuddyCodeEditorScreenState extends State<BuddyCodeEditorScreen>
    with TickerProviderStateMixin {
  final CodeEditorService _editorService = CodeEditorService();
  final SyncService _syncService = SyncService();

  late TabController _tabController;
  late TabController _sidebarController;

  List<CodeFile> _openFiles = [];
  int _currentFileIndex = 0;
  CodeProject? _currentProject;

  // Editor state
  bool _isSyncing = false;
  bool _isAutoSaveEnabled = true;
  bool _isDarkMode = true;
  String _selectedLanguage = 'dart';

  // Sidebar state
  List<ProjectItem> _projectFiles = [];

  // Search and replace
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  bool _showSearchPanel = false;

  // Terminal integration
  bool _showTerminal = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _sidebarController = TabController(length: 4, vsync: this);
    _initializeEditor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sidebarController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _editorService.dispose();
    _syncService.dispose();
    super.dispose();
  }

  Future<void> _initializeEditor() async {
    try {
      // Initialize services
      await _editorService.initialize();
      await _syncService.initialize();

      // Load project if provided
      if (widget.project != null) {
        await _loadProject(widget.project!);
      } else {
        await _createWelcomeProject();
      }

      // Start sync service
      _syncService.onFileChanged.listen(_handleFileSync);
      _syncService.onProjectChanged.listen(_handleProjectSync);

      setState(() {});
    } catch (e) {
      _showError('Failed to initialize editor: $e');
    }
  }

  Future<void> _loadProject(CodeProject project) async {
    _currentProject = project;
    _projectFiles = await _editorService.getProjectFiles(project.path);

    // Open main file if available
    if (project.mainFile.isNotEmpty) {
      await _openFile(project.mainFile);
    }

    // Load git status
    _loadGitStatus();
  }

  Future<void> _createWelcomeProject() async {
    _currentProject = CodeProject(
      id: 'welcome',
      name: 'Welcome to Buddy Code Editor',
      path: '/tmp/buddy_welcome',
      type: 'flutter',
      language: 'dart',
      mainFile: 'lib/main.dart',
      isRemote: false,
    );

    // Create welcome file
    final welcomeFile = CodeFile(
      path: 'lib/main.dart',
      name: 'main.dart',
      language: 'dart',
      content: _getWelcomeContent(),
      isModified: false,
    );

    _openFiles.add(welcomeFile);
    _updateTabController();
  }

  String _getWelcomeContent() {
    return '''// Welcome to Buddy Code Editor! 🚀
// 
// Features:
// • Cross-platform development (Mobile + Desktop)
// • Real-time sync with VS Code
// • Integrated terminal and git
// • Project templates and automation
// • Live collaboration
// • Intelligent code completion
// 
// Get started:
// 1. Create a new project (Ctrl+Shift+N)
// 2. Open existing project (Ctrl+O)  
// 3. Start coding with syntax highlighting
// 4. Use terminal for commands (Ctrl+`)
// 5. Sync with VS Code in real-time

import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddy Code Editor Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Buddy Code Editor'),
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
              'Welcome to Buddy Code Editor!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineLarge,
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
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        title: Text(_currentProject?.name ?? 'Buddy Code Editor'),
        backgroundColor: _isDarkMode ? const Color(0xFF2D2D30) : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Sync status
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // Language selector
          PopupMenuButton<String>(
            icon: Text(_selectedLanguage.toUpperCase()),
            onSelected: (language) {
              setState(() => _selectedLanguage = language);
              _editorService.setLanguage(language);
            },
            itemBuilder: (context) =>
                ['dart', 'python', 'javascript', 'java', 'kotlin', 'swift']
                    .map(
                      (lang) => PopupMenuItem(
                        value: lang,
                        child: Text(lang.toUpperCase()),
                      ),
                    )
                    .toList(),
          ),

          // Theme toggle
          IconButton(
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
          ),

          // Settings
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          SizedBox(width: 280, child: _buildSidebar()),

          // Vertical divider
          const VerticalDivider(width: 1),

          // Main editor area
          Expanded(
            child: Column(
              children: [
                // File tabs
                if (_openFiles.isNotEmpty) _buildFileTabs(),

                // Editor content
                Expanded(
                  flex: _showTerminal ? 2 : 1,
                  child: _buildEditorContent(),
                ),

                // Search panel
                if (_showSearchPanel) _buildSearchPanel(),

                // Terminal
                if (_showTerminal)
                  Expanded(flex: 1, child: _buildIntegratedTerminal()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: _isDarkMode ? const Color(0xFF252526) : Colors.grey[100],
      child: Column(
        children: [
          // Sidebar tabs
          TabBar(
            controller: _sidebarController,
            tabs: const [
              Tab(icon: Icon(Icons.folder_outlined), text: 'Files'),
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.source), text: 'Git'),
              Tab(icon: Icon(Icons.extension), text: 'Tools'),
            ],
            labelColor: _isDarkMode ? Colors.white : Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),

          // Sidebar content
          Expanded(
            child: TabBarView(
              controller: _sidebarController,
              children: [
                _buildFileExplorer(),
                _buildSearchPanel(),
                _buildGitPanel(),
                _buildToolsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Project header
        ListTile(
          leading: const Icon(Icons.folder, color: Colors.orange),
          title: Text(_currentProject?.name ?? 'No Project'),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_project',
                child: ListTile(
                  leading: Icon(Icons.create_new_folder),
                  title: Text('New Project'),
                ),
              ),
              const PopupMenuItem(
                value: 'open_project',
                child: ListTile(
                  leading: Icon(Icons.folder_open),
                  title: Text('Open Project'),
                ),
              ),
              const PopupMenuItem(
                value: 'sync_vscode',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Sync with VS Code'),
                ),
              ),
            ],
            onSelected: _handleProjectAction,
          ),
        ),

        const Divider(),

        // File tree
        ..._projectFiles.map((item) => _buildFileItem(item)),
      ],
    );
  }

  Widget _buildFileItem(ProjectItem item) {
    return ListTile(
      leading: Icon(
        item.isDirectory ? Icons.folder : _getFileIcon(item.name),
        color: item.isDirectory ? Colors.orange : Colors.blue,
        size: 18,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontSize: 13,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      onTap: () {
        if (item.isDirectory) {
          _toggleDirectory(item);
        } else {
          _openFile(item.path);
        }
      },
      trailing: item.isDirectory
          ? Icon(
              item.isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            )
          : null,
    );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'json':
        return Icons.data_object;
      case 'md':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildFileTabs() {
    return Container(
      height: 40,
      color: _isDarkMode ? const Color(0xFF2D2D30) : Colors.grey[200],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _openFiles.length,
        itemBuilder: (context, index) {
          final file = _openFiles[index];
          final isActive = index == _currentFileIndex;

          return Container(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
            decoration: BoxDecoration(
              color: isActive
                  ? (_isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
                  : null,
              border: Border(
                right: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(
                _getFileIcon(file.name),
                size: 16,
                color: isActive ? Colors.blue : Colors.grey,
              ),
              title: Text(
                file.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? (_isDarkMode ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (file.isModified)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _closeFile(index),
                    child: const Icon(Icons.close, size: 14),
                  ),
                ],
              ),
              onTap: () => setState(() => _currentFileIndex = index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorContent() {
    if (_openFiles.isEmpty) {
      return _buildWelcomeScreen();
    }

    final currentFile = _openFiles[_currentFileIndex];

    return Container(
      color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: TextField(
        controller: TextEditingController(text: currentFile.content),
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 14,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (content) {
          currentFile.content = content;
          currentFile.isModified = true;
          setState(() {});

          if (_isAutoSaveEnabled) {
            _autoSaveFile(currentFile);
          }
        },
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.code, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Buddy Code Editor',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cross-platform development with real-time sync',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _createNewProject,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('New Project'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _openExistingProject,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(); // Implement search functionality
  }

  Widget _buildGitPanel() {
    return Container(); // Implement git panel
  }

  Widget _buildToolsPanel() {
    return Container(); // Implement tools panel
  }

  Widget _buildIntegratedTerminal() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Integrated Terminal\n(Coming Soon)',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          mini: true,
          onPressed: () => setState(() => _showTerminal = !_showTerminal),
          child: Icon(_showTerminal ? Icons.terminal : Icons.code),
          tooltip: 'Toggle Terminal',
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: _runProject,
          child: const Icon(Icons.play_arrow),
          tooltip: 'Run Project',
        ),
      ],
    );
  }

  // Helper methods
  void _updateTabController() {
    _tabController.dispose();
    _tabController = TabController(length: _openFiles.length, vsync: this);
    setState(() {});
  }

  Future<void> _openFile(String path) async {
    // Implementation for opening files
  }

  void _closeFile(int index) {
    _openFiles.removeAt(index);
    if (_currentFileIndex >= _openFiles.length) {
      _currentFileIndex = _openFiles.length - 1;
    }
    _updateTabController();
  }

  void _toggleDirectory(ProjectItem item) {
    // Implementation for expanding/collapsing directories
  }

  void _handleProjectAction(String action) {
    switch (action) {
      case 'new_project':
        _createNewProject();
        break;
      case 'open_project':
        _openExistingProject();
        break;
      case 'sync_vscode':
        _syncWithVSCode();
        break;
    }
  }

  void _createNewProject() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProjectTemplatesScreen()),
    );
  }

  void _openExistingProject() {
    // Implementation for opening existing projects
  }

  void _syncWithVSCode() {
    // Implementation for VS Code sync
  }

  void _autoSaveFile(CodeFile file) {
    // Implementation for auto-saving files
  }

  void _runProject() {
    // Implementation for running projects
  }

  void _loadGitStatus() {
    // Implementation for loading git status
  }

  void _handleFileSync(CodeFile file) {
    // Implementation for handling file sync
  }

  void _handleProjectSync(CodeProject project) {
    // Implementation for handling project sync
  }

  void _showSettings() {
    // Implementation for showing settings
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
