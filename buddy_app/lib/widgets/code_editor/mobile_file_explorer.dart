// lib/widgets/code_editor/mobile_file_explorer.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../models/project_model.dart';
import '../../services/files/file_manager.dart';

class MobileFileExplorer extends StatefulWidget {
  final String rootPath;
  final Function(String) onFileSelected;
  final Function(String) onDirectoryChanged;
  final Function(String, bool) onFileCreated;
  final Function(String) onFileDeleted;
  final Function(String, String) onFileRenamed;
  final ProjectModel? currentProject;

  const MobileFileExplorer({
    super.key,
    required this.rootPath,
    required this.onFileSelected,
    required this.onDirectoryChanged,
    required this.onFileCreated,
    required this.onFileDeleted,
    required this.onFileRenamed,
    this.currentProject,
  });

  @override
  State<MobileFileExplorer> createState() => _MobileFileExplorerState();
}

class _MobileFileExplorerState extends State<MobileFileExplorer> {
  final FileManager _fileManager = FileManager();
  final Map<String, bool> _expandedDirectories = {};
  final Set<String> _selectedItems = {};
  String _currentPath = '';
  List<FileSystemEntity> _currentItems = [];
  bool _isLoading = false;
  bool _showHiddenFiles = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.rootPath;
    _loadDirectory(_currentPath);
  }

  @override
  void didUpdateWidget(MobileFileExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _currentPath = widget.rootPath;
      _loadDirectory(_currentPath);
    }
  }

  Future<void> _loadDirectory(String dirPath) async {
    setState(() => _isLoading = true);

    try {
      final items = await _fileManager.listDirectory(
        dirPath,
        showHidden: _showHiddenFiles,
      );

      setState(() {
        _currentItems = items;
        _currentPath = dirPath;
        _isLoading = false;
      });

      widget.onDirectoryChanged(dirPath);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load directory: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(),
          _buildBreadcrumb(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_open,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Explorer',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_hidden',
                child: Row(
                  children: [
                    Icon(
                      _showHiddenFiles
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showHiddenFiles
                          ? 'Hide Hidden Files'
                          : 'Show Hidden Files',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_file',
                child: Row(
                  children: [
                    Icon(Icons.note_add, size: 18),
                    SizedBox(width: 8),
                    Text('New File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_folder',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder, size: 18),
                    SizedBox(width: 8),
                    Text('New Folder'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'expand_all',
                child: Row(
                  children: [
                    Icon(Icons.unfold_more, size: 18),
                    SizedBox(width: 8),
                    Text('Expand All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'collapse_all',
                child: Row(
                  children: [
                    Icon(Icons.unfold_less, size: 18),
                    SizedBox(width: 8),
                    Text('Collapse All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final pathSegments = _currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home, size: 18),
            onPressed: () => _navigateToPath('/'),
            tooltip: 'Root',
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pathSegments.length,
              itemBuilder: (context, index) {
                final segment = pathSegments[index];
                final isLast = index == pathSegments.length - 1;
                final segmentPath =
                    '/' + pathSegments.sublist(0, index + 1).join('/');

                return Row(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    GestureDetector(
                      onTap: isLast ? null : () => _navigateToPath(segmentPath),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: isLast
                            ? BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              )
                            : null,
                        child: Text(
                          segment,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: isLast
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isLast
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_currentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Empty directory',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        return _buildFileItem(item);
      },
    );
  }

  Widget _buildFileItem(FileSystemEntity item) {
    final isDirectory = item is Directory;
    final fileName = path.basename(item.path);
    final isSelected = _selectedItems.contains(item.path);
    final isExpanded = _expandedDirectories[item.path] ?? false;

    return Column(
      children: [
        InkWell(
          onTap: () => _handleItemTap(item),
          onLongPress: () => _showContextMenu(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
            ),
            child: Row(
              children: [
                if (isDirectory) ...[
                  GestureDetector(
                    onTap: () => _toggleDirectory(item.path),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _buildFileIcon(item.path, isDirectory),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isDirectory
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isDirectory) ...[
                        const SizedBox(height: 2),
                        FutureBuilder<FileStat>(
                          future: item.stat(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final stat = snapshot.data!;
                              return Text(
                                _formatFileSize(stat.size),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isDirectory && _isExecutableFile(fileName)) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.play_arrow,
                      size: 20,
                      color: Colors.green,
                    ),
                    onPressed: () => widget.onFileSelected(item.path),
                    tooltip: 'Run',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 16),
                  onPressed: () => _showContextMenu(item),
                ),
              ],
            ),
          ),
        ),
        if (isDirectory && isExpanded)
          FutureBuilder<List<FileSystemEntity>>(
            future: _fileManager.listDirectory(
              item.path,
              showHidden: _showHiddenFiles,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(
                    children: snapshot.data!
                        .map((subItem) => _buildFileItem(subItem))
                        .toList(),
                  ),
                );
              } else if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: ListTile(
                    leading: const Icon(Icons.error, color: Colors.red),
                    title: Text('Error loading directory'),
                    subtitle: Text(snapshot.error.toString()),
                  ),
                );
              }
              return const Padding(
                padding: EdgeInsets.only(left: 32),
                child: ListTile(
                  leading: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Loading...'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFileIcon(String filePath, bool isDirectory) {
    if (isDirectory) {
      return Icon(Icons.folder, size: 20, color: Colors.blue);
    }

    final ext = path.extension(filePath).toLowerCase();
    IconData iconData;
    Color iconColor;

    switch (ext) {
      case '.dart':
        iconData = Icons.code;
        iconColor = Colors.blue;
        break;
      case '.js':
      case '.ts':
        iconData = Icons.javascript;
        iconColor = Colors.yellow.shade700;
        break;
      case '.py':
        iconData = Icons.code;
        iconColor = Colors.green;
        break;
      case '.java':
        iconData = Icons.coffee;
        iconColor = Colors.orange;
        break;
      case '.html':
        iconData = Icons.web;
        iconColor = Colors.orange;
        break;
      case '.css':
        iconData = Icons.css;
        iconColor = Colors.blue;
        break;
      case '.json':
        iconData = Icons.data_object;
        iconColor = Colors.orange;
        break;
      case '.md':
      case '.txt':
        iconData = Icons.description;
        iconColor = Colors.grey;
        break;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
        iconData = Icons.image;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Icon(iconData, size: 20, color: iconColor);
  }

  bool _isExecutableFile(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ['.dart', '.py', '.js', '.ts', '.java', '.cpp', '.c'].contains(ext);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _handleItemTap(FileSystemEntity item) {
    if (item is Directory) {
      _toggleDirectory(item.path);
    } else {
      widget.onFileSelected(item.path);
    }
  }

  void _toggleDirectory(String dirPath) {
    setState(() {
      _expandedDirectories[dirPath] = !(_expandedDirectories[dirPath] ?? false);
    });
  }

  void _navigateToPath(String newPath) {
    _loadDirectory(newPath);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _loadDirectory(_currentPath);
        break;
      case 'toggle_hidden':
        setState(() => _showHiddenFiles = !_showHiddenFiles);
        _loadDirectory(_currentPath);
        break;
      case 'new_file':
        _createNewItem(false);
        break;
      case 'new_folder':
        _createNewItem(true);
        break;
      case 'expand_all':
        _expandAllDirectories();
        break;
      case 'collapse_all':
        _collapseAllDirectories();
        break;
    }
  }

  void _expandAllDirectories() {
    setState(() {
      for (final item in _currentItems) {
        if (item is Directory) {
          _expandedDirectories[item.path] = true;
        }
      }
    });
  }

  void _collapseAllDirectories() {
    setState(() {
      _expandedDirectories.clear();
    });
  }

  Future<void> _createNewItem(bool isDirectory) async {
    final name = await _showCreateDialog(isDirectory);
    if (name != null && name.isNotEmpty) {
      final newPath = path.join(_currentPath, name);
      widget.onFileCreated(newPath, isDirectory);
      _loadDirectory(_currentPath);
    }
  }

  void _showContextMenu(FileSystemEntity item) {
    final isDirectory = item is Directory;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameItem(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
          ),
          if (!isDirectory && _isExecutableFile(path.basename(item.path)))
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: const Text('Run'),
              onTap: () {
                Navigator.pop(context);
                widget.onFileSelected(item.path);
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Path'),
            onTap: () {
              Navigator.pop(context);
              _copyPath(item.path);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameItem(FileSystemEntity item) async {
    final currentName = path.basename(item.path);
    final newName = await _showRenameDialog(currentName);

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final newPath = path.join(path.dirname(item.path), newName);
      widget.onFileRenamed(item.path, newPath);
      _loadDirectory(_currentPath);
    }
  }

  Future<void> _deleteItem(FileSystemEntity item) async {
    final confirmed = await _showConfirmDialog(
      'Delete ${item is Directory ? 'Folder' : 'File'}',
      'Are you sure you want to delete ${path.basename(item.path)}?',
    );

    if (confirmed) {
      widget.onFileDeleted(item.path);
      _loadDirectory(_currentPath);
    }
  }

  void _copyPath(String itemPath) {
    // TODO: Implement clipboard copy
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Path copied: $itemPath')));
  }

  Future<String?> _showCreateDialog(bool isDirectory) async {
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

  Future<String?> _showRenameDialog(String currentName) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
