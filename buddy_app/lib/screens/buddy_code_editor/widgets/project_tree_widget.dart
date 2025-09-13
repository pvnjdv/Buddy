import 'package:flutter/material.dart';
import '../models/project_structure.dart';

class ProjectTreeWidget extends StatefulWidget {
  final ProjectStructure structure;
  final Function(String) onFileSelected;
  final Function(String) onFileContextMenu;
  final Function(String) onDirectoryContextMenu;
  final String? selectedFilePath;

  const ProjectTreeWidget({
    super.key,
    required this.structure,
    required this.onFileSelected,
    required this.onFileContextMenu,
    required this.onDirectoryContextMenu,
    this.selectedFilePath,
  });

  @override
  State<ProjectTreeWidget> createState() => _ProjectTreeWidgetState();
}

class _ProjectTreeWidgetState extends State<ProjectTreeWidget> {
  Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _initializeExpandedStates(widget.structure);
  }

  void _initializeExpandedStates(ProjectStructure structure) {
    if (structure.isDirectory) {
      _expandedStates[structure.path] = structure.isExpanded;
      for (final child in structure.children) {
        _initializeExpandedStates(child);
      }
    }
  }

  void _toggleExpanded(String path) {
    setState(() {
      _expandedStates[path] = !(_expandedStates[path] ?? false);
    });
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').length > 1
        ? fileName.split('.').last.toLowerCase()
        : '';

    switch (extension) {
      case 'dart':
        return Icons.flutter_dash;
      case 'js':
      case 'jsx':
        return Icons.javascript;
      case 'ts':
      case 'tsx':
        return Icons.code;
      case 'py':
        return Icons.data_object;
      case 'java':
        return Icons.coffee;
      case 'html':
        return Icons.web;
      case 'css':
      case 'scss':
      case 'sass':
        return Icons.style;
      case 'json':
        return Icons.data_object_outlined;
      case 'md':
        return Icons.article;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileName) {
    final extension = fileName.split('.').length > 1
        ? fileName.split('.').last.toLowerCase()
        : '';

    switch (extension) {
      case 'dart':
        return const Color(0xFF0175C2);
      case 'js':
      case 'jsx':
        return const Color(0xFFF7DF1E);
      case 'ts':
      case 'tsx':
        return const Color(0xFF3178C6);
      case 'py':
        return const Color(0xFF3776AB);
      case 'java':
        return const Color(0xFFED8B00);
      case 'html':
        return const Color(0xFFE34F26);
      case 'css':
      case 'scss':
      case 'sass':
        return const Color(0xFF1572B6);
      case 'json':
        return const Color(0xFF000000);
      case 'md':
        return const Color(0xFF083FA1);
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildTreeItem(ProjectStructure item, int depth) {
    final isExpanded = _expandedStates[item.path] ?? false;
    final isSelected = widget.selectedFilePath == item.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (item.isDirectory) {
              _toggleExpanded(item.path);
            } else {
              widget.onFileSelected(item.path);
            }
          },
          onLongPress: () {
            if (item.isDirectory) {
              widget.onDirectoryContextMenu(item.path);
            } else {
              widget.onFileContextMenu(item.path);
            }
          },
          child: Container(
            padding: EdgeInsets.only(
              left: (depth * 16.0) + 8.0,
              right: 8.0,
              top: 4.0,
              bottom: 4.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                if (item.isDirectory) ...[
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.folder_open : Icons.folder,
                    size: 16,
                    color: const Color(0xFFFFB74D),
                  ),
                ] else ...[
                  const SizedBox(width: 20),
                  Icon(
                    _getFileIcon(item.name),
                    size: 16,
                    color: _getFileIconColor(item.name),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (item.isDirectory && isExpanded)
          ...item.children.map((child) => _buildTreeItem(child, depth + 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FILES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () =>
                      widget.onDirectoryContextMenu(widget.structure.path),
                  tooltip: 'New file',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildTreeItem(widget.structure, 0),
            ),
          ),
        ],
      ),
    );
  }
}
