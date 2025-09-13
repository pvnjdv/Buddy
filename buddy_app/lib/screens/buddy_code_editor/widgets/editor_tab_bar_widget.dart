import 'package:flutter/material.dart';
import '../models/editor_file.dart';
import '../models/editor_theme.dart';

class EditorTabBarWidget extends StatefulWidget {
  final List<EditorFile> openFiles;
  final EditorFile? activeFile;
  final Function(EditorFile) onTabSelected;
  final Function(EditorFile) onTabClosed;
  final EditorTheme theme;

  const EditorTabBarWidget({
    super.key,
    required this.openFiles,
    required this.activeFile,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.theme,
  });

  @override
  State<EditorTabBarWidget> createState() => _EditorTabBarWidgetState();
}

class _EditorTabBarWidgetState extends State<EditorTabBarWidget> {
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

  Widget _buildTab(EditorFile file) {
    final isActive = widget.activeFile?.path == file.path;

    return GestureDetector(
      onTap: () => widget.onTabSelected(file),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
        decoration: BoxDecoration(
          color: isActive
              ? widget.theme.backgroundColor
              : widget.theme.surfaceColor,
          border: Border(
            right: BorderSide(color: widget.theme.gutterColor, width: 1),
            bottom: isActive
                ? BorderSide.none
                : BorderSide(color: widget.theme.gutterColor, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(file.name),
                size: 14,
                color: _getFileIconColor(file.name),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? widget.theme.textColor
                        : widget.theme.textColor.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (file.isModified) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.theme.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.onTabClosed(file),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: widget.theme.textColor.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openFiles.isEmpty) {
      return Container(
        height: 35,
        decoration: BoxDecoration(
          color: widget.theme.surfaceColor,
          border: Border(
            bottom: BorderSide(color: widget.theme.gutterColor, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            'No files open',
            style: TextStyle(
              fontSize: 12,
              color: widget.theme.textColor.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: widget.theme.gutterColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: widget.openFiles.map(_buildTab).toList()),
            ),
          ),
          // Tab controls
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: widget.theme.gutterColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: widget.theme.textColor.withOpacity(0.6),
                  ),
                  onPressed: () {
                    // Show dropdown with all open files
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: 'More files',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
