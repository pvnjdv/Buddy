import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../models/dock_models.dart';
import '../../models/code_editor_models.dart';
import '../../services/sync_service.dart';
import '../../services/code_editor_service.dart';
import '../../services/file_manager_service.dart';
import '../../services/code_execution_service.dart';

class EnhancedBuddyCodeEditor extends StatefulWidget {
  final Device? device;
  final CodeProject? project;
  final bool isStandalone;

  const EnhancedBuddyCodeEditor({
    super.key,
    this.device,
    this.project,
    this.isStandalone = false,
  });

  @override
  State<EnhancedBuddyCodeEditor> createState() =>
      _EnhancedBuddyCodeEditorState();
}

class _EnhancedBuddyCodeEditorState extends State<EnhancedBuddyCodeEditor>
    with TickerProviderStateMixin {
  // Core editor state
  List<CodeFile> _openFiles = [];
  int _currentFileIndex = 0;
  late TabController _tabController;
  late TabController _sidebarController;

  // File management
  final Map<String, TextEditingController> _fileControllers = {};
  final Map<String, bool> _fileModified = {};
  final FileManagerService _fileManager = FileManagerService();
  final CodeExecutionService _codeExecution = CodeExecutionService();
  String _currentDirectory = '/home/pvn/Desktop/Buddy/buddy_app';

  // UI state
  bool _showSidebar = true;
  bool _showTerminal = false;
  bool _showSearchPanel = false;
  bool _isFullscreen = false;
  bool _isDarkMode = false;
  bool _isAutoSaveEnabled = true;
  double _sidebarWidth = 250;

  // Terminal
  String _terminalOutputText = '';
  final ScrollController _terminalScrollController = ScrollController();
  final List<String> _terminalHistory = [];
  int _terminalHistoryIndex = -1;
  final TextEditingController _terminalInputController =
      TextEditingController();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  int _currentSearchIndex = 0;
  List<TextSelection> _searchResults = [];

  // Services
  SyncService? _syncService;
  CodeEditorService? _codeEditorService;
  CodeProject? _currentProject;
  List<String> _projectFiles = [];
  String _selectedLanguage = 'dart';
  bool _isSyncing = false;

  // Enhanced features
  bool _showMinimap = true;
  bool _showLineNumbers = true;
  bool _enableCodeCompletion = true;
  bool _enableSyntaxHighlighting = true;
  bool _wrapText = false;
  int _fontSize = 14;
  String _fontFamily = 'JetBrains Mono';

  // Git integration
  String _currentBranch = 'main';
  List<String> _gitChangedFiles = [];

  // Plugin system
  final Map<String, bool> _enabledPlugins = {
    'auto_save': true,
    'code_completion': true,
    'error_checking': true,
    'git_integration': true,
    'file_watcher': true,
  };

  // Undo/Redo system
  final Map<String, List<String>> _undoHistory = {};
  final Map<String, int> _undoIndex = {};
  Timer? _autoSaveTimer;
  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    _tabController = TabController(length: 0, vsync: this);
    _sidebarController = TabController(length: 4, vsync: this);

    if (widget.device != null) {
      _syncService = SyncService();
      await _syncService?.initialize();
    }

    _codeEditorService = CodeEditorService();
    _currentProject = widget.project;

    if (_currentProject != null) {
      await _loadProjectFiles();
    } else {
      await _createWelcomeProject();
    }

    // Setup keyboard shortcuts
    _setupKeyboardShortcuts();
  }

  void _setupKeyboardShortcuts() {
    // Keyboard shortcuts are handled in the build method with KeyboardListener
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sidebarController.dispose();
    _terminalScrollController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _terminalInputController.dispose();
    _autoSaveTimer?.cancel();

    for (final controller in _fileControllers.values) {
      controller.dispose();
    }

    _syncService?.dispose();
    super.dispose();
  }

  Future<void> _loadProjectFiles() async {
    if (_currentProject != null) {
      try {
        final files = await _fileManager.getLocalFiles(_currentProject!.path);
        setState(() {
          _projectFiles = files.map((f) => f.path).toList();
        });
      } catch (e) {
        _showError('Failed to load project files: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Column(
          children: [
            // Menu bar
            _buildMenuBar(),

            // Main content
            Expanded(
              child: Stack(
                children: [
                  // Main editor layout
                  Row(
                    children: [
                      // Sidebar
                      if (_showSidebar && !_isFullscreen)
                        Container(
                          width: _sidebarWidth,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: _buildSidebar(),
                        ),

                      // Editor area
                      Expanded(
                        child: Column(
                          children: [
                            // Tab bar
                            if (_openFiles.isNotEmpty) _buildTabBar(),

                            // Editor content
                            Expanded(
                              child: _openFiles.isEmpty
                                  ? _buildWelcomeScreen()
                                  : _buildEditor(),
                            ),

                            // Terminal
                            if (_showTerminal) _buildTerminal(),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Search panel overlay
                  if (_showSearchPanel)
                    Positioned(top: 50, right: 20, child: _buildSearchPanel()),
                ],
              ),
            ),

            // Status bar
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (HardwareKeyboard.instance.isControlPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyN:
            _createNewFile();
            break;
          case LogicalKeyboardKey.keyS:
            if (_openFiles.isNotEmpty) {
              _saveFile(_openFiles[_currentFileIndex].path);
            }
            break;
          case LogicalKeyboardKey.keyF:
            setState(() => _showSearchPanel = !_showSearchPanel);
            break;
          case LogicalKeyboardKey.keyH:
            setState(() => _showSearchPanel = true);
            break;
          case LogicalKeyboardKey.backquote:
            setState(() => _showTerminal = !_showTerminal);
            break;
          case LogicalKeyboardKey.keyB:
            _toggleSidebar();
            break;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        _runCode();
      } else if (event.logicalKey == LogicalKeyboardKey.f11) {
        _toggleFullscreen();
      }
    }
  }

  Widget _buildMenuBar() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildMenuButton('File', [
            _buildMenuItem('New File', Icons.add, _createNewFile),
            _buildMenuItem(
              'New Folder',
              Icons.create_new_folder,
              _createNewFolder,
            ),
            _buildMenuDivider(),
            _buildMenuItem('Open File', Icons.folder_open, _openFileDialog),
            _buildMenuItem('Open Folder', Icons.folder, _openFolderDialog),
            _buildMenuDivider(),
            _buildMenuItem('Save', Icons.save, _saveCurrentFile),
            _buildMenuItem('Save As', Icons.save_as, _saveAsDialog),
            _buildMenuItem('Save All', Icons.save_alt, _saveAllFiles),
            _buildMenuDivider(),
            _buildMenuItem('Export Project', Icons.archive, _exportProject),
            _buildMenuItem('Import Project', Icons.unarchive, _importProject),
          ]),
          _buildMenuButton('Edit', [
            _buildMenuItem('Undo', Icons.undo, _performUndo),
            _buildMenuItem('Redo', Icons.redo, _performRedo),
            _buildMenuDivider(),
            _buildMenuItem('Cut', Icons.content_cut, _cutText),
            _buildMenuItem('Copy', Icons.content_copy, _copyText),
            _buildMenuItem('Paste', Icons.content_paste, _pasteText),
            _buildMenuDivider(),
            _buildMenuItem(
              'Find',
              Icons.search,
              () => setState(() => _showSearchPanel = true),
            ),
            _buildMenuItem(
              'Find and Replace',
              Icons.find_replace,
              _showFindReplace,
            ),
            _buildMenuItem('Go to Line', Icons.my_location, _showGoToLine),
            _buildMenuDivider(),
            _buildMenuItem('Format Document', Icons.code, _formatDocument),
            _buildMenuItem('Sort Lines', Icons.sort, _sortLines),
          ]),
          _buildMenuButton('View', [
            _buildMenuItem(
              'Toggle Sidebar',
              Icons.view_sidebar,
              _toggleSidebar,
            ),
            _buildMenuItem(
              'Toggle Terminal',
              Icons.terminal,
              () => setState(() => _showTerminal = !_showTerminal),
            ),
            _buildMenuItem(
              'Toggle Minimap',
              Icons.map,
              () => setState(() => _showMinimap = !_showMinimap),
            ),
            _buildMenuItem(
              'Toggle Line Numbers',
              Icons.format_list_numbered,
              () => setState(() => _showLineNumbers = !_showLineNumbers),
            ),
            _buildMenuDivider(),
            _buildMenuItem('Zoom In', Icons.zoom_in, _zoomIn),
            _buildMenuItem('Zoom Out', Icons.zoom_out, _zoomOut),
            _buildMenuItem('Reset Zoom', Icons.zoom_out_map, _resetZoom),
            _buildMenuDivider(),
            _buildMenuItem(
              'Toggle Fullscreen',
              Icons.fullscreen,
              _toggleFullscreen,
            ),
            _buildMenuItem('Split Editor', Icons.splitscreen, _splitEditor),
          ]),
          _buildMenuButton('Run', [
            _buildMenuItem('Run Code', Icons.play_arrow, _runCode),
            _buildMenuItem('Debug Code', Icons.bug_report, _debugCode),
            _buildMenuItem('Stop Execution', Icons.stop, _stopExecution),
            _buildMenuDivider(),
            _buildMenuItem('Run Tests', Icons.assignment_turned_in, _runTests),
            _buildMenuItem('Build Project', Icons.build, _buildProject),
          ]),
          _buildMenuButton('Git', [
            _buildMenuItem(
              'Clone Repository',
              Icons.cloud_download,
              _cloneRepository,
            ),
            _buildMenuItem('Pull', Icons.cloud_download, _gitPull),
            _buildMenuItem('Push', Icons.cloud_upload, _gitPush),
            _buildMenuDivider(),
            _buildMenuItem('Commit', Icons.save_alt, _gitCommit),
            _buildMenuItem('View History', Icons.history, _viewGitHistory),
            _buildMenuItem('Branches', Icons.account_tree, _viewBranches),
          ]),
          _buildMenuButton('Tools', [
            _buildMenuItem(
              'Command Palette',
              Icons.palette,
              _showCommandPalette,
            ),
            _buildMenuItem(
              'Extension Manager',
              Icons.extension,
              _showExtensions,
            ),
            _buildMenuItem('Settings', Icons.settings, _showSettings),
            _buildMenuDivider(),
            _buildMenuItem('Generate Code', Icons.auto_awesome, _generateCode),
            _buildMenuItem('Refactor', Icons.transform, _showRefactorMenu),
          ]),
          const Spacer(),
          // Status indicators
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            iconSize: 16,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showQuickSettings,
            iconSize: 16,
            tooltip: 'Quick Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String title, List<Widget> items) {
    return PopupMenuButton<void>(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(title, style: const TextStyle(fontSize: 13)),
      ),
      itemBuilder: (context) =>
          items.map((item) => PopupMenuItem(child: item)).toList(),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 16),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Sidebar tabs
        TabBar(
          controller: _sidebarController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.folder, size: 20)),
            Tab(icon: Icon(Icons.search, size: 20)),
            Tab(icon: Icon(Icons.extension, size: 20)),
            Tab(icon: Icon(Icons.settings, size: 20)),
          ],
        ),

        // Sidebar content
        Expanded(
          child: TabBarView(
            controller: _sidebarController,
            children: [
              _buildFileExplorer(),
              _buildGlobalSearch(),
              _buildExtensions(),
              _buildSettings(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue,
        tabs: _openFiles.map((file) {
          final isModified = _fileModified[file.path] ?? false;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isModified)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.circle, size: 6, color: Colors.orange),
                  ),
                Text(file.name, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _closeFile(_openFiles.indexOf(file)),
                  child: const Icon(Icons.close, size: 14),
                ),
              ],
            ),
          );
        }).toList(),
        onTap: (index) => setState(() => _currentFileIndex = index),
      ),
    );
  }

  Widget _buildEditor() {
    return TabBarView(
      controller: _tabController,
      children: _openFiles.map((file) => _buildCodeEditor(file)).toList(),
    );
  }

  Widget _buildWelcomeScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Welcome to Buddy Code Editor',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Press Ctrl+N to create a new file or use the file explorer',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer() {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: const Border(
              bottom: BorderSide(color: Colors.grey, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 16,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                'Explorer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _createNewFile,
                iconSize: 16,
                tooltip: 'New File',
              ),
              IconButton(
                icon: Icon(
                  Icons.create_new_folder,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _createNewFolder,
                iconSize: 16,
                tooltip: 'New Folder',
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() {}),
                iconSize: 16,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Current directory path
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _isDarkMode ? Colors.grey[850] : Colors.grey[50],
          child: Text(
            _currentDirectory.split('/').last.isNotEmpty
                ? _currentDirectory.split('/').last
                : 'Root',
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ),

        Expanded(
          child: Container(
            color: _isDarkMode ? Colors.grey[900] : Colors.white,
            child: FutureBuilder<List<dynamic>>(
              future: _fileManager.getLocalFiles(_currentDirectory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading files',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          color: _isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[400],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Empty folder',
                          style: TextStyle(
                            color: _isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!;

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entity = items[index];
                    final name = entity.path.split('/').last;
                    final isDir = entity.toString().contains('Directory');
                    final isGitFile = name.startsWith('.');
                    final isModified = _gitChangedFiles.contains(entity.path);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isModified
                            ? (_isDarkMode
                                  ? Colors.orange[900]
                                  : Colors.orange[50])
                            : null,
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFileIcon(name, isDir),
                              size: 16,
                              color: _getFileIconColor(name, isDir),
                            ),
                            if (isModified) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            color: isGitFile
                                ? (_isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600])
                                : (_isDarkMode ? Colors.white : Colors.black),
                            fontWeight: isDir
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isDir
                            ? Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: _isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              )
                            : null,
                        onTap: () {
                          if (isDir) {
                            setState(() => _currentDirectory = entity.path);
                          } else {
                            _openFileFromPath(entity.path);
                          }
                        },
                        onLongPress: () =>
                            _showFileContextMenu(entity.path, isDir),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String fileName, bool isDirectory) {
    if (isDirectory) return Icons.folder;

    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'py':
        return Icons.code;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'html':
        return Icons.web;
      case 'css':
        return Icons.style;
      case 'json':
        return Icons.data_object;
      case 'md':
        return Icons.article;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'tar':
      case 'gz':
        return Icons.archive;
      case 'txt':
        return Icons.description;
      case 'gradle':
        return Icons.build;
      case 'xml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileName, bool isDirectory) {
    if (isDirectory) return Colors.blue;

    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return Colors.blue;
      case 'py':
        return Colors.green;
      case 'js':
      case 'ts':
        return Colors.yellow[700]!;
      case 'html':
        return Colors.orange;
      case 'css':
        return Colors.blue[300]!;
      case 'json':
        return Colors.teal;
      case 'md':
        return Colors.grey[600]!;
      case 'yaml':
      case 'yml':
        return Colors.purple;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Colors.pink;
      case 'pdf':
        return Colors.red;
      case 'zip':
      case 'tar':
      case 'gz':
        return Colors.amber;
      default:
        return _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }

  void _showFileContextMenu(String filePath, bool isDirectory) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filePath.split('/').last,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (!isDirectory)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open'),
                  onTap: () {
                    Navigator.pop(context);
                    _openFileFromPath(filePath);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _renameFile(filePath);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  _copyFile(filePath);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(filePath);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _renameFile(String filePath) {
    final currentName = filePath.split('/').last;
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'New name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement file rename
                Navigator.pop(context);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _copyFile(String filePath) {
    // TODO: Implement file copy
    _showError('File copy not implemented yet');
  }

  void _deleteFile(String filePath) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Are you sure you want to delete ${filePath.split('/').last}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                // TODO: Implement file deletion
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalSearch() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Search in files',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          SizedBox(height: 16),
          Text('Search results will appear here'),
        ],
      ),
    );
  }

  Widget _buildExtensions() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Extensions', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Extension marketplace coming soon...'),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (value) => setState(() => _isDarkMode = value),
          ),
          SwitchListTile(
            title: const Text('Auto Save'),
            value: _isAutoSaveEnabled,
            onChanged: (value) => setState(() => _isAutoSaveEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(CodeFile file) {
    final lines = file.content.split('\n');
    final lineCount = lines.length;

    return Container(
      color: _isDarkMode ? Colors.grey[900] : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers
          if (_showLineNumbers)
            Container(
              width: 60,
              color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 1; i <= lineCount; i++)
                    Container(
                      height: 20,
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: _fontSize.toDouble() - 2,
                          fontFamily: _fontFamily,
                          color: _isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Main editor
          Expanded(
            child: Stack(
              children: [
                // Background with syntax highlighting
                Container(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _fileControllers[file.path],
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: _fontSize.toDouble(),
                      color: _isDarkMode ? Colors.white : Colors.black,
                      height: 1.2,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Start typing...',
                      hintStyle: TextStyle(
                        color: _isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ),
                    onChanged: (content) {
                      _updateFileContent(file.path, content);
                      _addToUndoHistory(file.path, content);
                    },
                    onTap: () {
                      // Update cursor position
                      _updateCursorPosition(file.path);
                    },
                  ),
                ),

                // Current line highlight
                if (_enableSyntaxHighlighting)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: _buildSyntaxHighlight(file),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Minimap
          if (_showMinimap)
            Container(
              width: 100,
              color: _isDarkMode ? Colors.grey[850] : Colors.grey[50],
              child: _buildMinimap(file),
            ),
        ],
      ),
    );
  }

  Widget _buildSyntaxHighlight(CodeFile file) {
    // Basic syntax highlighting for common languages
    final language = file.language.toLowerCase();
    final lines = file.content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((line) => _buildHighlightedLine(line, language))
          .toList(),
    );
  }

  Widget _buildHighlightedLine(String line, String language) {
    // Basic syntax highlighting implementation
    final spans = <TextSpan>[];

    switch (language) {
      case 'dart':
        spans.addAll(_getDartSyntaxSpans(line));
        break;
      case 'python':
        spans.addAll(_getPythonSyntaxSpans(line));
        break;
      case 'javascript':
        spans.addAll(_getJavaScriptSyntaxSpans(line));
        break;
      default:
        spans.add(
          TextSpan(
            text: line,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: _fontSize.toDouble(),
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        );
    }

    return Container(
      height: 20,
      alignment: Alignment.centerLeft,
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  List<TextSpan> _getDartSyntaxSpans(String line) {
    // Dart keywords
    final keywords = [
      'class',
      'void',
      'int',
      'String',
      'bool',
      'double',
      'var',
      'final',
      'const',
      'if',
      'else',
      'for',
      'while',
      'return',
      'import',
      'library',
      'part',
      'extends',
      'implements',
      'with',
      'abstract',
      'static',
      'async',
      'await',
    ];

    final spans = <TextSpan>[];
    final words = line.split(RegExp(r'\s+'));

    for (final word in words) {
      Color color = _isDarkMode ? Colors.white : Colors.black;

      if (keywords.contains(word)) {
        color = Colors.purple; // Keywords
      } else if (word.startsWith('//')) {
        color = Colors.green; // Comments
      } else if (word.startsWith('"') || word.startsWith("'")) {
        color = Colors.orange; // Strings
      } else if (RegExp(r'^\d+$').hasMatch(word)) {
        color = Colors.blue; // Numbers
      }

      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: _fontSize.toDouble(),
            color: color,
          ),
        ),
      );
    }

    return spans;
  }

  List<TextSpan> _getPythonSyntaxSpans(String line) {
    final keywords = [
      'def',
      'class',
      'if',
      'else',
      'elif',
      'for',
      'while',
      'return',
      'import',
      'from',
      'as',
      'try',
      'except',
      'finally',
      'with',
      'lambda',
    ];

    return _getGenericSyntaxSpans(line, keywords);
  }

  List<TextSpan> _getJavaScriptSyntaxSpans(String line) {
    final keywords = [
      'function',
      'var',
      'let',
      'const',
      'if',
      'else',
      'for',
      'while',
      'return',
      'class',
      'extends',
      'import',
      'export',
      'async',
      'await',
    ];

    return _getGenericSyntaxSpans(line, keywords);
  }

  List<TextSpan> _getGenericSyntaxSpans(String line, List<String> keywords) {
    final spans = <TextSpan>[];
    final words = line.split(RegExp(r'\s+'));

    for (final word in words) {
      Color color = _isDarkMode ? Colors.white : Colors.black;

      if (keywords.contains(word)) {
        color = Colors.purple;
      } else if (word.startsWith('//') || word.startsWith('#')) {
        color = Colors.green;
      } else if (word.startsWith('"') || word.startsWith("'")) {
        color = Colors.orange;
      } else if (RegExp(r'^\d+$').hasMatch(word)) {
        color = Colors.blue;
      }

      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: _fontSize.toDouble(),
            color: color,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildMinimap(CodeFile file) {
    final lines = file.content.split('\n');
    const lineHeight = 2.0;

    return SingleChildScrollView(
      child: Column(
        children: lines.asMap().entries.map((entry) {
          final line = entry.value;

          return Container(
            height: lineHeight,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 0.5),
            decoration: BoxDecoration(
              color: line.trim().isEmpty
                  ? Colors.transparent
                  : (_isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _updateFileContent(String filePath, String content) {
    setState(() {
      _fileModified[filePath] = true;
      final index = _openFiles.indexWhere((file) => file.path == filePath);
      if (index != -1) {
        _openFiles[index] = _openFiles[index].copyWith(
          content: content,
          isModified: true,
        );
      }
    });

    if (_isAutoSaveEnabled) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 2), () {
        _saveFile(filePath);
      });
    }
  }

  void _addToUndoHistory(String filePath, String content) {
    _undoHistory[filePath] ??= [];
    _undoHistory[filePath]!.add(content);

    // Keep only last 50 states
    if (_undoHistory[filePath]!.length > 50) {
      _undoHistory[filePath]!.removeAt(0);
    }

    _undoIndex[filePath] = _undoHistory[filePath]!.length - 1;
  }

  void _updateCursorPosition(String filePath) {
    // Update cursor position for status bar
    // This would be implemented with more sophisticated text analysis
  }

  Widget _buildSearchPanel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Find and Replace',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showSearchPanel = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Find',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replaceController,
              decoration: const InputDecoration(
                labelText: 'Replace',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement find
                  },
                  child: const Text('Find'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement replace
                  },
                  child: const Text('Replace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            height: 32,
            color: Colors.grey.shade800,
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Terminal',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () => setState(() => _terminalOutputText = ''),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _showTerminal = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: SingleChildScrollView(
                controller: _terminalScrollController,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _terminalOutputText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final currentFile = _openFiles.isNotEmpty
        ? _openFiles[_currentFileIndex]
        : null;
    final controller = currentFile != null
        ? _fileControllers[currentFile.path]
        : null;
    final cursorPosition = _getCursorPosition(controller);
    final lineCount = currentFile?.content.split('\n').length ?? 0;
    final characterCount = currentFile?.content.length ?? 0;
    final isModified = currentFile != null
        ? (_fileModified[currentFile.path] ?? false)
        : false;

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.blue,
        border: Border(
          top: BorderSide(
            color: _isDarkMode ? Colors.grey[700]! : Colors.blue.shade700,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Sync status
          Icon(
            _isSyncing
                ? Icons.sync
                : (widget.device?.isOnline == true
                      ? Icons.cloud
                      : Icons.cloud_off),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            widget.device?.name ?? 'Local',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),

          const SizedBox(width: 16),

          // Git status
          if (_currentBranch.isNotEmpty) ...[
            Icon(Icons.account_tree, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              _currentBranch,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 16),
          ],

          // File info
          if (currentFile != null) ...[
            Text(
              currentFile.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: isModified ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isModified) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const SizedBox(width: 16),
          ],

          const Spacer(),

          // Editor info
          if (currentFile != null) ...[
            // Cursor position
            Text(
              'Ln ${cursorPosition['line']}, Col ${cursorPosition['column']}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 8),

            // File stats
            Text(
              '$lineCount lines, $characterCount chars',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 8),

            // Language
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                currentFile.language.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
            const SizedBox(width: 8),

            // Encoding
            Text(
              'UTF-8',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 8),

            // Font size
            Text(
              '${_fontSize}px',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],

          // Quick settings
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showQuickSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Icon(Icons.settings, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getCursorPosition(TextEditingController? controller) {
    if (controller == null) {
      return {'line': 1, 'column': 1};
    }

    final text = controller.text;
    final selection = controller.selection;

    if (selection.baseOffset < 0 || selection.baseOffset > text.length) {
      return {'line': 1, 'column': 1};
    }

    final beforeCursor = text.substring(0, selection.baseOffset);
    final lines = beforeCursor.split('\n');
    final line = lines.length;
    final column = lines.last.length + 1;

    return {'line': line, 'column': column};
  }

  // Methods
  void _createNewFile() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New File'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Filename',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final filename = controller.text.trim();
                if (filename.isNotEmpty) {
                  await _createAndOpenNewFile(filename);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createAndOpenNewFile(String filename) async {
    final filePath = '$_currentDirectory/$filename';
    final result = await _fileManager.createFile(filePath);

    if (result.success) {
      final newFile = CodeFile(
        path: filePath,
        name: filename,
        content: '',
        language: _fileManager.getLanguageFromExtension(filename),
        isModified: false,
      );

      setState(() {
        _openFiles.add(newFile);
        _fileModified[filePath] = false;
        _fileControllers[filePath] = TextEditingController();
        _tabController = TabController(length: _openFiles.length, vsync: this);
        _currentFileIndex = _openFiles.length - 1;
        _tabController.index = _currentFileIndex;
      });
    } else {
      _showError('Failed to create file: ${result.message}');
    }
  }

  Future<void> _openFileFromPath(String filePath) async {
    final existingIndex = _openFiles.indexWhere(
      (file) => file.path == filePath,
    );
    if (existingIndex != -1) {
      setState(() {
        _currentFileIndex = existingIndex;
        _tabController.index = existingIndex;
      });
      return;
    }

    final result = await _fileManager.readFile(filePath);
    if (result.success && result.content != null) {
      final filename = _fileManager.getFileName(filePath);
      final newFile = CodeFile(
        path: filePath,
        name: filename,
        content: result.content!,
        language: _fileManager.getLanguageFromExtension(filename),
        isModified: false,
      );

      setState(() {
        _openFiles.add(newFile);
        _fileModified[filePath] = false;
        _fileControllers[filePath] = TextEditingController(
          text: result.content,
        );
        _tabController = TabController(length: _openFiles.length, vsync: this);
        _currentFileIndex = _openFiles.length - 1;
        _tabController.index = _currentFileIndex;
      });
    } else {
      _showError('Error opening file: ${result.message}');
    }
  }

  Future<void> _saveCurrentFile() async {
    if (_openFiles.isNotEmpty) {
      await _saveFile(_openFiles[_currentFileIndex].path);
    }
  }

  Future<void> _saveAllFiles() async {
    for (final file in _openFiles) {
      if (_fileModified[file.path] == true) {
        await _saveFile(file.path);
      }
    }
  }

  Future<void> _saveFile(String filePath) async {
    final content = _fileControllers[filePath]?.text ?? '';
    final result = await _fileManager.writeFile(filePath, content);

    if (result.success) {
      setState(() {
        _fileModified[filePath] = false;
        final index = _openFiles.indexWhere((file) => file.path == filePath);
        if (index != -1) {
          _openFiles[index] = _openFiles[index].copyWith(
            content: content,
            isModified: false,
          );
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File saved successfully')));
    } else {
      _showError('Failed to save file: ${result.message}');
    }
  }

  void _runCode() async {
    if (_openFiles.isEmpty || _currentFileIndex >= _openFiles.length) return;

    final file = _openFiles[_currentFileIndex];
    final language = _fileManager.getLanguageFromExtension(file.name);

    setState(() => _showTerminal = true);
    _appendToTerminal('Running ${file.name}...\n');

    try {
      await for (final result in _codeExecution.executeCodeStream(
        code: file.content,
        language: language,
        filename: file.name,
      )) {
        _appendToTerminal('Status: ${result.status.name}\n');
        if (result.output.isNotEmpty) {
          _appendToTerminal('Output:\n${result.output}\n');
        }
        if (result.error.isNotEmpty) {
          _appendToTerminal('Error:\n${result.error}\n');
        }

        if (!result.isRunning) {
          _appendToTerminal('\nExecution completed\n');
          break;
        }
      }
    } catch (e) {
      _appendToTerminal('Error: $e\n');
    }
  }

  void _appendToTerminal(String text) {
    setState(() => _terminalOutputText += text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showSidebar = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleSidebar() {
    setState(() => _showSidebar = !_showSidebar);
  }

  void _closeFile(int index) {
    if (_fileModified[_openFiles[index].path] == true) {
      _showUnsavedChangesDialog(index);
    } else {
      _forceCloseFile(index);
    }
  }

  void _forceCloseFile(int index) {
    setState(() {
      final file = _openFiles.removeAt(index);
      _fileControllers[file.path]?.dispose();
      _fileControllers.remove(file.path);
      _fileModified.remove(file.path);

      if (_openFiles.isEmpty) {
        _tabController = TabController(length: 0, vsync: this);
        _currentFileIndex = 0;
      } else {
        _tabController = TabController(length: _openFiles.length, vsync: this);
        if (index > 0) {
          _currentFileIndex = index - 1;
          _tabController.index = _currentFileIndex;
        }
      }
    });
  }

  void _showUnsavedChangesDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
          'Do you want to save changes to ${_openFiles[index].name}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _forceCloseFile(index);
            },
            child: const Text("Don't Save"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveFile(
                _openFiles[index].path,
              ).then((_) => _forceCloseFile(index));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _performUndo() {
    // TODO: Implement undo functionality
  }

  void _performRedo() {
    // TODO: Implement redo functionality
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _createWelcomeProject() async {
    // Create a welcome project if no project is provided
    _currentProject = CodeProject(
      id: 'welcome',
      name: 'Welcome Project',
      path: _currentDirectory,
      type: 'flutter',
      language: 'dart',
      mainFile: 'main.dart',
      isRemote: false,
    );
  }

  // Enhanced Menu Helper Methods
  Widget _buildMenuDivider() {
    return const Divider(height: 1);
  }

  // File Operations
  void _createNewFolder() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement folder creation
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _openFolderDialog() {
    // TODO: Implement folder picker
    _showError('Folder picker not implemented yet');
  }

  void _openFileDialog() {
    // TODO: Implement file picker
    _showError('File picker not implemented yet');
  }

  void _saveAsDialog() {
    // TODO: Implement save as dialog
    _showError('Save as dialog not implemented yet');
  }

  void _exportProject() {
    // TODO: Implement project export
    _showError('Project export not implemented yet');
  }

  void _importProject() {
    // TODO: Implement project import
    _showError('Project import not implemented yet');
  }

  // Edit Operations
  void _cutText() {
    // TODO: Implement cut operation
    Clipboard.setData(const ClipboardData(text: ''));
  }

  void _copyText() {
    // TODO: Implement copy operation
    Clipboard.setData(const ClipboardData(text: ''));
  }

  void _pasteText() async {
    // TODO: Implement paste operation
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      // Paste text at cursor position
    }
  }

  void _showFindReplace() {
    setState(() => _showSearchPanel = true);
  }

  void _showGoToLine() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Go to Line'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Line number',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement go to line
                Navigator.pop(context);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _formatDocument() {
    // TODO: Implement document formatting
    _showError('Document formatting not implemented yet');
  }

  void _sortLines() {
    // TODO: Implement line sorting
    _showError('Line sorting not implemented yet');
  }

  // View Operations
  void _zoomIn() {
    setState(() {
      _fontSize = (_fontSize + 1).clamp(8, 32);
    });
  }

  void _zoomOut() {
    setState(() {
      _fontSize = (_fontSize - 1).clamp(8, 32);
    });
  }

  void _resetZoom() {
    setState(() {
      _fontSize = 14;
    });
  }

  void _splitEditor() {
    // TODO: Implement editor splitting
    _showError('Editor splitting not implemented yet');
  }

  // Run Operations
  void _debugCode() {
    // TODO: Implement code debugging
    _showError('Code debugging not implemented yet');
  }

  void _stopExecution() {
    // TODO: Implement execution stopping
    _showError('Stop execution not implemented yet');
  }

  void _runTests() {
    // TODO: Implement test running
    _showError('Test running not implemented yet');
  }

  void _buildProject() {
    // TODO: Implement project building
    _showError('Project building not implemented yet');
  }

  // Git Operations
  void _cloneRepository() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Clone Repository'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Repository URL',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement repository cloning
                Navigator.pop(context);
              },
              child: const Text('Clone'),
            ),
          ],
        );
      },
    );
  }

  void _gitPull() {
    // TODO: Implement git pull
    _showError('Git pull not implemented yet');
  }

  void _gitPush() {
    // TODO: Implement git push
    _showError('Git push not implemented yet');
  }

  void _gitCommit() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Commit Changes'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Commit message',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement git commit
                Navigator.pop(context);
              },
              child: const Text('Commit'),
            ),
          ],
        );
      },
    );
  }

  void _viewGitHistory() {
    // TODO: Implement git history view
    _showError('Git history not implemented yet');
  }

  void _viewBranches() {
    // TODO: Implement branch view
    _showError('Branch view not implemented yet');
  }

  // Tools Operations
  void _showCommandPalette() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Command Palette'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Type a command...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showExtensions() {
    // TODO: Implement extension manager
    _showError('Extension manager not implemented yet');
  }

  void _showSettings() {
    // TODO: Implement settings dialog
    _showError('Settings dialog not implemented yet');
  }

  void _generateCode() {
    // TODO: Implement AI code generation
    _showError('Code generation not implemented yet');
  }

  void _showRefactorMenu() {
    // TODO: Implement refactor menu
    _showError('Refactor menu not implemented yet');
  }

  // Theme and UI
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _showQuickSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: _isDarkMode,
                    onChanged: (value) {
                      setModalState(() => _isDarkMode = value);
                      setState(() => _isDarkMode = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Auto Save'),
                    value: _isAutoSaveEnabled,
                    onChanged: (value) {
                      setModalState(() => _isAutoSaveEnabled = value);
                      setState(() => _isAutoSaveEnabled = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show Minimap'),
                    value: _showMinimap,
                    onChanged: (value) {
                      setModalState(() => _showMinimap = value);
                      setState(() => _showMinimap = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show Line Numbers'),
                    value: _showLineNumbers,
                    onChanged: (value) {
                      setModalState(() => _showLineNumbers = value);
                      setState(() => _showLineNumbers = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Word Wrap'),
                    value: _wrapText,
                    onChanged: (value) {
                      setModalState(() => _wrapText = value);
                      setState(() => _wrapText = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Font Size: '),
                      Expanded(
                        child: Slider(
                          value: _fontSize.toDouble(),
                          min: 8,
                          max: 32,
                          divisions: 24,
                          label: _fontSize.toString(),
                          onChanged: (value) {
                            setModalState(() => _fontSize = value.round());
                            setState(() => _fontSize = value.round());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
