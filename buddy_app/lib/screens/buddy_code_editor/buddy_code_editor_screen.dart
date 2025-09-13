import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project_model.dart';
import 'models/editor_file.dart';
import 'models/editor_theme.dart';
import 'models/project_structure.dart';
import 'services/file_service.dart';
import 'widgets/project_tree_widget.dart';
import 'widgets/code_editor_widget.dart';
import 'widgets/editor_tab_bar_widget.dart';

// Providers for state management
final openFilesProvider = StateProvider<List<EditorFile>>((ref) => []);
final activeFileProvider = StateProvider<EditorFile?>((ref) => null);
final editorThemeProvider = StateProvider<EditorTheme>(
  (ref) => EditorTheme.buddyDark,
);
final projectStructureProvider = StateProvider<ProjectStructure?>(
  (ref) => null,
);

class BuddyCodeEditorScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const BuddyCodeEditorScreen({super.key, required this.project});

  @override
  ConsumerState<BuddyCodeEditorScreen> createState() =>
      _BuddyCodeEditorScreenState();
}

class _BuddyCodeEditorScreenState extends ConsumerState<BuddyCodeEditorScreen>
    with TickerProviderStateMixin {
  String? _error;
  bool _isLoading = true;
  bool _showMobileSidebar = false;

  @override
  void initState() {
    super.initState();
    _loadProjectStructure();
  }

  Future<void> _loadProjectStructure() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final structure = await FileService.getProjectStructure(
        widget.project.path,
      );
      ref.read(projectStructureProvider.notifier).state = structure;

      // Load main.dart if it exists
      final mainDartPath = '${widget.project.path}/lib/main.dart';
      try {
        final mainFile = await FileService.readFile(mainDartPath);
        ref.read(openFilesProvider.notifier).state = [mainFile];
        ref.read(activeFileProvider.notifier).state = mainFile;
      } catch (e) {
        // main.dart doesn't exist, that's okay
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final file = await FileService.readFile(filePath);
      final openFiles = ref.read(openFilesProvider);
      final existingIndex = openFiles.indexWhere((f) => f.path == file.path);

      if (existingIndex >= 0) {
        ref.read(activeFileProvider.notifier).state = openFiles[existingIndex];
      } else {
        ref.read(openFilesProvider.notifier).state = [...openFiles, file];
        ref.read(activeFileProvider.notifier).state = file;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _closeFile(EditorFile file) {
    final openFiles = ref.read(openFilesProvider);
    final updatedFiles = openFiles.where((f) => f.path != file.path).toList();
    ref.read(openFilesProvider.notifier).state = updatedFiles;

    final activeFile = ref.read(activeFileProvider);
    if (activeFile?.path == file.path) {
      ref.read(activeFileProvider.notifier).state = updatedFiles.isNotEmpty
          ? updatedFiles.last
          : null;
    }
  }

  void _selectTab(EditorFile file) {
    ref.read(activeFileProvider.notifier).state = file;
  }

  void _onFileContentChanged(String content) {
    final activeFile = ref.read(activeFileProvider);
    if (activeFile != null) {
      final updatedFile = activeFile.copyWith(
        content: content,
        isModified: true,
      );

      final openFiles = ref.read(openFilesProvider);
      final index = openFiles.indexWhere((f) => f.path == activeFile.path);
      if (index >= 0) {
        final updatedFiles = [...openFiles];
        updatedFiles[index] = updatedFile;
        ref.read(openFilesProvider.notifier).state = updatedFiles;
        ref.read(activeFileProvider.notifier).state = updatedFile;
      }
    }
  }

  Future<void> _saveFile(EditorFile file) async {
    try {
      await FileService.saveFile(file);

      final openFiles = ref.read(openFilesProvider);
      final index = openFiles.indexWhere((f) => f.path == file.path);
      if (index >= 0) {
        final updatedFile = file.copyWith(isModified: false);
        final updatedFiles = [...openFiles];
        updatedFiles[index] = updatedFile;
        ref.read(openFilesProvider.notifier).state = updatedFiles;

        final activeFile = ref.read(activeFileProvider);
        if (activeFile?.path == file.path) {
          ref.read(activeFileProvider.notifier).state = updatedFile;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showNewFileDialog(String directoryPath) {
    showDialog(
      context: context,
      builder: (context) => _NewFileDialog(
        directoryPath: directoryPath,
        onFileCreated: _openFile,
      ),
    );
  }

  void _showNewFolderDialog(String directoryPath) {
    showDialog(
      context: context,
      builder: (context) => _NewFolderDialog(
        directoryPath: directoryPath,
        onFolderCreated: () {
          _loadProjectStructure(); // Refresh project structure
        },
      ),
    );
  }

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => _TemplateDialog(
        onTemplateSelected: (template) => _createFileFromTemplate(template),
      ),
    );
  }

  Future<void> _createFileFromTemplate(FileTemplate template) async {
    try {
      final fileName = '${template.name.toLowerCase().replaceAll(' ', '_')}.${template.extension}';
      final filePath = '${widget.project.path}/$fileName';
      
      final file = EditorFile(
        name: fileName,
        path: filePath,
        content: template.content,
        language: template.language,
        isNew: true,
        isModified: true,
        lastModified: DateTime.now(),
      );

      // Add to open files and set as active
      final openFiles = ref.read(openFilesProvider);
      ref.read(openFilesProvider.notifier).state = [...openFiles, file];
      ref.read(activeFileProvider.notifier).state = file;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${template.name} template'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildToolbar() {
    final theme = ref.watch(editorThemeProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(bottom: BorderSide(color: theme.gutterColor, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            widget.project.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const Spacer(),
          PopupMenuButton<EditorTheme>(
            icon: Icon(Icons.palette_outlined, color: theme.primaryColor),
            onSelected: (theme) {
              ref.read(editorThemeProvider.notifier).state = theme;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: EditorTheme.buddyDark,
                child: Text('Buddy Dark'),
              ),
              const PopupMenuItem(
                value: EditorTheme.buddyLight,
                child: Text('Buddy Light'),
              ),
              const PopupMenuItem(
                value: EditorTheme.monokai,
                child: Text('Monokai'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    final theme = ref.watch(editorThemeProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.code,
                size: 80,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to Buddy Code Editor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Professional code editing experience\noptimized for mobile development',
              style: TextStyle(
                fontSize: 16,
                color: theme.textColor.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Quick actions grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildQuickActionCard(
                  context,
                  theme,
                  'New File',
                  Icons.note_add,
                  'Create a new file',
                  () => _showNewFileDialog(widget.project.path),
                ),
                _buildQuickActionCard(
                  context,
                  theme,
                  'New Folder',
                  Icons.create_new_folder,
                  'Create a new folder',
                  () => _showNewFolderDialog(widget.project.path),
                ),
                _buildQuickActionCard(
                  context,
                  theme,
                  'Open File',
                  Icons.folder_open,
                  'Browse project files',
                  () {
                    setState(() {
                      _showMobileSidebar = true;
                    });
                  },
                ),
                _buildQuickActionCard(
                  context,
                  theme,
                  'Templates',
                  Icons.library_books,
                  'Use file templates',
                  () => _showTemplateDialog(),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Get started section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.gutterColor,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Tap the folder icon to browse files\n'
                    '• Use horizontal scrolling for tabs\n'
                    '• Pinch to zoom in/out\n'
                    '• Long press for context menu',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textColor.withOpacity(0.7),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    EditorTheme theme,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.gutterColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: theme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(EditorTheme theme) {
    final projectStructure = ref.watch(projectStructureProvider);
    final openFiles = ref.watch(openFilesProvider);
    final activeFile = ref.watch(activeFileProvider);

    return Stack(
      children: [
        // Main editor area
        Column(
          children: [
            // Mobile tab bar with folder toggle
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                border: Border(
                  bottom: BorderSide(color: theme.gutterColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Folder toggle button
                  IconButton(
                    icon: Icon(
                      _showMobileSidebar ? Icons.folder_open : Icons.folder,
                      color: theme.primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showMobileSidebar = !_showMobileSidebar;
                      });
                    },
                  ),
                  // Horizontal scrollable tabs
                  Expanded(
                    child: openFiles.isEmpty
                        ? Center(
                            child: Text(
                              'No files open',
                              style: TextStyle(
                                color: theme.textColor.withOpacity(0.6),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: openFiles.map((file) {
                                final isActive = file == activeFile;
                                return GestureDetector(
                                  onTap: () => _selectTab(file),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? theme.backgroundColor
                                          : theme.surfaceColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: isActive
                                          ? Border.all(
                                              color: theme.primaryColor,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          file.name,
                                          style: TextStyle(
                                            color: isActive
                                                ? theme.primaryColor
                                                : theme.textColor,
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (file.isModified) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _closeFile(file),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: theme.textColor.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  // Add file button
                  IconButton(
                    icon: Icon(Icons.add, color: theme.primaryColor),
                    onPressed: () {
                      if (projectStructure != null) {
                        _showNewFileDialog(widget.project.path);
                      }
                    },
                  ),
                ],
              ),
            ),
            // Editor content
            Expanded(
              child: activeFile != null
                  ? CodeEditorWidget(
                      file: activeFile,
                      theme: theme,
                      onContentChanged: _onFileContentChanged,
                      onSave: () => _saveFile(activeFile),
                      onClose: () => _closeFile(activeFile),
                    )
                  : _buildWelcomeScreen(),
            ),
          ],
        ),
        // Sliding sidebar
        if (_showMobileSidebar && projectStructure != null)
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              border: Border(
                right: BorderSide(color: theme.gutterColor, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Sidebar header
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    border: Border(
                      bottom: BorderSide(color: theme.gutterColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Project Explorer',
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.textColor.withOpacity(0.6),
                        ),
                        onPressed: () {
                          setState(() {
                            _showMobileSidebar = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Project tree
                Expanded(
                  child: ProjectTreeWidget(
                    structure: projectStructure,
                    onFileSelected: (path) {
                      _openFile(path);
                      setState(() {
                        _showMobileSidebar = false;
                      });
                    },
                    onFileContextMenu: (path) => _showNewFileDialog(path),
                    onDirectoryContextMenu: (path) => _showNewFileDialog(path),
                    selectedFilePath: activeFile?.path,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopLayout(EditorTheme theme) {
    final projectStructure = ref.watch(projectStructureProvider);
    final openFiles = ref.watch(openFilesProvider);
    final activeFile = ref.watch(activeFileProvider);

    return Row(
      children: [
        // Project tree sidebar
        if (projectStructure != null)
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              border: Border(
                right: BorderSide(color: theme.gutterColor, width: 1),
              ),
            ),
            child: ProjectTreeWidget(
              structure: projectStructure,
              onFileSelected: _openFile,
              onFileContextMenu: (path) => _showNewFileDialog(path),
              onDirectoryContextMenu: (path) => _showNewFileDialog(path),
              selectedFilePath: activeFile?.path,
            ),
          ),
        // Editor area
        Expanded(
          child: Column(
            children: [
              // Tab bar
              EditorTabBarWidget(
                openFiles: openFiles,
                activeFile: activeFile,
                onTabSelected: _selectTab,
                onTabClosed: _closeFile,
                theme: theme,
              ),
              // Editor content
              Expanded(
                child: activeFile != null
                    ? CodeEditorWidget(
                        file: activeFile,
                        theme: theme,
                        onContentChanged: _onFileContentChanged,
                        onSave: () => _saveFile(activeFile),
                        onClose: () => _closeFile(activeFile),
                      )
                    : _buildWelcomeScreen(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(editorThemeProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Loading project...',
                style: TextStyle(color: theme.textColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 80, color: theme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Error loading project',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.textColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProjectStructure,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 800;

                  if (isMobile) {
                    return _buildMobileLayout(theme);
                  } else {
                    return _buildDesktopLayout(theme);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewFileDialog extends StatefulWidget {
  final String directoryPath;
  final Function(String) onFileCreated;

  const _NewFileDialog({
    required this.directoryPath,
    required this.onFileCreated,
  });

  @override
  State<_NewFileDialog> createState() => _NewFileDialogState();
}

class _NewFileDialogState extends State<_NewFileDialog> {
  final _controller = TextEditingController();
  bool _isCreating = false;

  Future<void> _createFile() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final fileName = _controller.text.trim();
      final file = await FileService.createNewFile(
        widget.directoryPath,
        fileName,
      );

      Navigator.of(context).pop();
      widget.onFileCreated(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New File'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'File name',
              hintText: 'example.dart',
            ),
            autofocus: true,
            onSubmitted: (_) => _createFile(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createFile,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _NewFolderDialog extends StatefulWidget {
  final String directoryPath;
  final VoidCallback onFolderCreated;

  const _NewFolderDialog({
    required this.directoryPath,
    required this.onFolderCreated,
  });

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController();
  bool _isCreating = false;

  Future<void> _createFolder() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final folderName = _controller.text.trim();
      await FileService.createDirectory('${widget.directoryPath}/$folderName');

      Navigator.of(context).pop();
      widget.onFolderCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'my-folder',
            ),
            autofocus: true,
            onSubmitted: (_) => _createFolder(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createFolder,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class FileTemplate {
  final String name;
  final String extension;
  final String language;
  final String content;
  final IconData icon;

  const FileTemplate({
    required this.name,
    required this.extension,
    required this.language,
    required this.content,
    required this.icon,
  });

  static List<FileTemplate> get defaultTemplates => [
    FileTemplate(
      name: 'Dart Class',
      extension: 'dart',
      language: 'dart',
      icon: Icons.class_,
      content: '''class MyClass {
  // Add your properties here
  
  MyClass();
  
  // Add your methods here
}''',
    ),
    FileTemplate(
      name: 'Flutter Widget',
      extension: 'dart',
      language: 'dart',
      icon: Icons.widgets,
      content: '''import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Text('Hello, Buddy!'),
    );
  }
}''',
    ),
    FileTemplate(
      name: 'Flutter Screen',
      extension: 'dart',
      language: 'dart',
      icon: Icons.phone_android,
      content: '''import 'package:flutter/material.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Screen'),
      ),
      body: const Center(
        child: Text('Welcome to My Screen!'),
      ),
    );
  }
}''',
    ),
    FileTemplate(
      name: 'JSON File',
      extension: 'json',
      language: 'json',
      icon: Icons.data_object,
      content: '''{
  "name": "buddy-project",
  "version": "1.0.0",
  "description": "Created with Buddy"
}''',
    ),
    FileTemplate(
      name: 'README',
      extension: 'md',
      language: 'markdown',
      icon: Icons.article,
      content: '''# My Project

Created with Buddy Code Editor

## Features

- Feature 1
- Feature 2
- Feature 3

## Getting Started

Instructions for getting started...
''',
    ),
  ];
}

class _TemplateDialog extends StatelessWidget {
  final Function(FileTemplate) onTemplateSelected;

  const _TemplateDialog({required this.onTemplateSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Template'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: FileTemplate.defaultTemplates.length,
          itemBuilder: (context, index) {
            final template = FileTemplate.defaultTemplates[index];
            return ListTile(
              leading: Icon(template.icon, color: Theme.of(context).primaryColor),
              title: Text(template.name),
              subtitle: Text('.${template.extension} • ${template.language}'),
              onTap: () {
                Navigator.of(context).pop();
                onTemplateSelected(template);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
