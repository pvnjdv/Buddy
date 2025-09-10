// lib/widgets/code_editor/mobile_bottom_bar.dart
import 'package:flutter/material.dart';
import '../../models/file_model.dart';

class MobileBottomBar extends StatelessWidget {
  final FileModel? currentFile;
  final Function(String) onQuickAction;
  final VoidCallback onToggleExplorer;
  final VoidCallback onOpenCommandPalette;

  const MobileBottomBar({
    super.key,
    this.currentFile,
    required this.onQuickAction,
    required this.onToggleExplorer,
    required this.onOpenCommandPalette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomBarButton(
            icon: Icons.folder_open,
            label: 'Explorer',
            onTap: onToggleExplorer,
          ),
          _buildBottomBarButton(
            icon: Icons.search,
            label: 'Search',
            onTap: () => onQuickAction('search'),
          ),
          _buildBottomBarButton(
            icon: Icons.save,
            label: 'Save',
            onTap: () => onQuickAction('save'),
            enabled: currentFile?.isModified ?? false,
          ),
          _buildBottomBarButton(
            icon: Icons.play_arrow,
            label: 'Run',
            onTap: () => onQuickAction('run'),
            enabled: currentFile?.isExecutable ?? false,
            color: Colors.green,
          ),
          _buildBottomBarButton(
            icon: Icons.terminal,
            label: 'Terminal',
            onTap: () => onQuickAction('terminal'),
          ),
          _buildBottomBarButton(
            icon: Icons.palette,
            label: 'Commands',
            onTap: onOpenCommandPalette,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    Color? color,
  }) {
    return Expanded(
      child: Builder(
        builder: (context) => InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled
                      ? (color ?? Theme.of(context).colorScheme.onSurface)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
