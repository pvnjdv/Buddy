// lib/widgets/code_editor/enhanced_file_tree.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class EnhancedFileTree extends StatefulWidget {
  final String projectPath;
  final Function(String) onFileSelected;
  final Function(String, String) onFileRenamed;
  final Function(String) onFileDeleted;
  final Function(String, bool) onFileCreated;
  final Function(String)? onRunFile;
  final List<String> openFiles;

  const EnhancedFileTree({
    super.key,
    required this.projectPath,
    required this.onFileSelected,
    required this.onFileRenamed,
    required this.onFileDeleted,
    required this.onFileCreated,
    this.onRunFile,
    this.openFiles = const [],
  });

  @override
  State<EnhancedFileTree> createState() => _EnhancedFileTreeState();
}

class _EnhancedFileTreeState extends State<EnhancedFileTree> {
  final Map<String, bool> _expandedDirectories = {};
  final Set<String> _selectedFiles = {};
  String? _renamingFile;
  final TextEditingController _renameController = TextEditingController();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Auto-expand the root directory
    _expandedDirectories[widget.projectPath] = true;
  }

  @override
  void dispose() {
    _renameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<FileSystemEntity>> _getDirectoryContents(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final contents = await dir.list().toList();

      // Sort: directories first, then files, alphabetically
      contents.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        return path
            .basename(a.path)
            .toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase());
      });

      return contents;
    } catch (e) {
      return [];
    }
  }

  Widget _buildFileIcon(String filePath, bool isDirectory) {
    if (isDirectory) {
      final isExpanded = _expandedDirectories[filePath] ?? false;
      return Icon(
        isExpanded ? Icons.folder_open : Icons.folder,
        size: 18,
        color: Colors.blue,
      );
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
      case '.jsx':
      case '.tsx':
        iconData = Icons.web;
        iconColor = Colors.cyan;
        break;
      case '.py':
        iconData = Icons.code;
        iconColor = Colors.green;
        break;
      case '.java':
        iconData = Icons.coffee;
        iconColor = Colors.orange;
        break;
      case '.cpp':
      case '.c':
      case '.h':
        iconData = Icons.code;
        iconColor = Colors.indigo;
        break;
      case '.html':
        iconData = Icons.html;
        iconColor = Colors.orange;
        break;
      case '.css':
      case '.scss':
      case '.sass':
        iconData = Icons.css;
        iconColor = Colors.blue;
        break;
      case '.json':
        iconData = Icons.data_object;
        iconColor = Colors.orange;
        break;
      case '.xml':
        iconData = Icons.code;
        iconColor = Colors.purple;
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
      case '.svg':
        iconData = Icons.image;
        iconColor = Colors.purple;
        break;
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.zip':
      case '.rar':
      case '.tar':
        iconData = Icons.archive;
        iconColor = Colors.brown;
        break;
      case '.exe':
      case '.app':
        iconData = Icons.play_circle;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Icon(iconData, size: 18, color: iconColor);
  }

  bool _isRunnableFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.dart', '.py', '.js', '.ts', '.java', '.cpp', '.c'].contains(ext);
  }

  void _showContextMenu(
    BuildContext context,
    String filePath,
    bool isDirectory,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      items: <PopupMenuEntry<String>>[
        if (!isDirectory && _isRunnableFile(filePath)) ...[
          PopupMenuItem<String>(
            value: 'run',
            child: const Row(
              children: [
                Icon(Icons.play_arrow, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text('Run File'),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<String>(
          value: 'rename',
          child: const Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
        if (isDirectory) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'new_file',
            child: const Row(
              children: [
                Icon(Icons.note_add, size: 18),
                SizedBox(width: 8),
                Text('New File'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'new_folder',
            child: const Row(
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text('New Folder'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: (_expandedDirectories[filePath] ?? false)
                ? 'collapse_all'
                : 'expand_all',
            child: Row(
              children: [
                Icon(
                  (_expandedDirectories[filePath] ?? false)
                      ? Icons.unfold_less
                      : Icons.unfold_more,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  (_expandedDirectories[filePath] ?? false)
                      ? 'Collapse All'
                      : 'Expand All',
                ),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy_path',
          child: const Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy Path'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reveal_in_explorer',
          child: const Row(
            children: [
              Icon(Icons.folder_open, size: 18),
              SizedBox(width: 8),
              Text('Reveal in Explorer'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleContextMenuAction(value, filePath, isDirectory);
      }
    });
  }

  void _handleContextMenuAction(
    String action,
    String filePath,
    bool isDirectory,
  ) {
    switch (action) {
      case 'run':
        if (widget.onRunFile != null) {
          widget.onRunFile!(filePath);
        }
        break;
      case 'rename':
        _startRenaming(filePath);
        break;
      case 'delete':
        _confirmDelete(filePath);
        break;
      case 'new_file':
        _createNewFile(filePath, false);
        break;
      case 'new_folder':
        _createNewFile(filePath, true);
        break;
      case 'expand_all':
        _expandAllDirectories(filePath);
        break;
      case 'collapse_all':
        _collapseAllDirectories(filePath);
        break;
      case 'copy_path':
        _copyPathToClipboard(filePath);
        break;
      case 'reveal_in_explorer':
        _revealInExplorer(filePath);
        break;
    }
  }

  void _expandAllDirectories(String basePath) {
    setState(() {
      _expandDirectory(basePath, true);
    });
  }

  void _collapseAllDirectories(String basePath) {
    setState(() {
      _expandDirectory(basePath, false);
    });
  }

  void _expandDirectory(String dirPath, bool expand) {
    if (FileSystemEntity.isDirectorySync(dirPath)) {
      _expandedDirectories[dirPath] = expand;
      try {
        final dir = Directory(dirPath);
        final contents = dir.listSync();
        for (final item in contents) {
          if (item is Directory) {
            _expandDirectory(item.path, expand);
          }
        }
      } catch (e) {
        // Ignore permission errors
      }
    }
  }

  void _copyPathToClipboard(String filePath) {
    Clipboard.setData(ClipboardData(text: filePath));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Path copied: $filePath')));
  }

  void _revealInExplorer(String filePath) {
    // TODO: Implement platform-specific file explorer opening
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reveal in explorer not implemented')),
    );
  }

  void _startRenaming(String filePath) {
    setState(() {
      _renamingFile = filePath;
      _renameController.text = path.basename(filePath);
    });
  }

  void _confirmRename() {
    if (_renamingFile != null && _renameController.text.isNotEmpty) {
      final oldPath = _renamingFile!;
      final newName = _renameController.text;
      final newPath = path.join(path.dirname(oldPath), newName);

      widget.onFileRenamed(oldPath, newPath);

      setState(() {
        _renamingFile = null;
        _renameController.clear();
      });
    }
  }

  void _cancelRename() {
    setState(() {
      _renamingFile = null;
      _renameController.clear();
    });
  }

  void _confirmDelete(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${path.basename(filePath)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onFileDeleted(filePath);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createNewFile(String parentPath, bool isDirectory) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Create New ${isDirectory ? 'Folder' : 'File'}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: isDirectory ? 'Folder name' : 'File name',
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
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  final newPath = path.join(parentPath, controller.text);
                  widget.onFileCreated(newPath, isDirectory);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFileTreeItem(String filePath, int depth) {
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);
    final fileName = path.basename(filePath);
    final isSelected = _selectedFiles.contains(filePath);
    final isOpen = widget.openFiles.contains(filePath);
    final isRenaming = _renamingFile == filePath;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (isDirectory) {
              setState(() {
                _expandedDirectories[filePath] =
                    !(_expandedDirectories[filePath] ?? false);
              });
            } else {
              widget.onFileSelected(filePath);
            }
          },
          onSecondaryTap: () =>
              _showContextMenu(context, filePath, isDirectory),
          child: Container(
            padding: EdgeInsets.only(left: depth * 16.0 + 8),
            height: 32,
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
            child: Row(
              children: [
                if (isDirectory) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedDirectories[filePath] =
                            !(_expandedDirectories[filePath] ?? false);
                      });
                    },
                    child: Icon(
                      (_expandedDirectories[filePath] ?? false)
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _buildFileIcon(filePath, isDirectory),
                const SizedBox(width: 8),
                Expanded(
                  child: isRenaming
                      ? TextField(
                          controller: _renameController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onSubmitted: (_) => _confirmRename(),
                          onTapOutside: (_) => _cancelRename(),
                          autofocus: true,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isOpen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isOpen
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOpen)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (!isDirectory && _isRunnableFile(filePath))
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    if (widget.onRunFile != null) {
                                      widget.onRunFile!(filePath);
                                    }
                                  },
                                  child: const Icon(
                                    Icons.play_circle_outline,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        if (isDirectory && (_expandedDirectories[filePath] ?? false))
          FutureBuilder<List<FileSystemEntity>>(
            future: _getDirectoryContents(filePath),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              return Column(
                children: snapshot.data!
                    .map((entity) => _buildFileTreeItem(entity.path, depth + 1))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header with controls
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 18),
                const SizedBox(width: 8),
                Text('Files', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.unfold_more, size: 18),
                  onPressed: () => _expandAllDirectories(widget.projectPath),
                  tooltip: 'Expand All',
                ),
                IconButton(
                  icon: const Icon(Icons.unfold_less, size: 18),
                  onPressed: () => _collapseAllDirectories(widget.projectPath),
                  tooltip: 'Collapse All',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => setState(() {}),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // File tree
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: _buildFileTreeItem(widget.projectPath, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
