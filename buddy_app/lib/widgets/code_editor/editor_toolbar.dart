// lib/widgets/code_editor/editor_toolbar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onFind;
  final VoidCallback? onReplace;
  final VoidCallback? onComment;
  final VoidCallback? onFormat;
  final VoidCallback? onRun;
  final VoidCallback? onDebug;
  final VoidCallback? onTerminal;
  final VoidCallback? onSettings;
  final bool canUndo;
  final bool canRedo;
  final bool isRunning;
  final String? currentLanguage;
  final List<String> availableLanguages;
  final Function(String)? onLanguageChanged;

  const EditorToolbar({
    super.key,
    this.onSave,
    this.onUndo,
    this.onRedo,
    this.onCut,
    this.onCopy,
    this.onPaste,
    this.onFind,
    this.onReplace,
    this.onComment,
    this.onFormat,
    this.onRun,
    this.onDebug,
    this.onTerminal,
    this.onSettings,
    this.canUndo = false,
    this.canRedo = false,
    this.isRunning = false,
    this.currentLanguage,
    this.availableLanguages = const [],
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // File operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.save,
              tooltip: 'Save (Ctrl+S)',
              onPressed: onSave,
            ),
          ]),

          const VerticalDivider(),

          // Edit operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: canUndo ? onUndo : null,
            ),
            _buildToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onPressed: canRedo ? onRedo : null,
            ),
          ]),

          const VerticalDivider(),

          // Clipboard operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.cut,
              tooltip: 'Cut (Ctrl+X)',
              onPressed: onCut,
            ),
            _buildToolbarButton(
              icon: Icons.copy,
              tooltip: 'Copy (Ctrl+C)',
              onPressed: onCopy,
            ),
            _buildToolbarButton(
              icon: Icons.paste,
              tooltip: 'Paste (Ctrl+V)',
              onPressed: onPaste,
            ),
          ]),

          const VerticalDivider(),

          // Search operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.search,
              tooltip: 'Find (Ctrl+F)',
              onPressed: onFind,
            ),
            _buildToolbarButton(
              icon: Icons.find_replace,
              tooltip: 'Replace (Ctrl+H)',
              onPressed: onReplace,
            ),
          ]),

          const VerticalDivider(),

          // Code operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.comment,
              tooltip: 'Toggle Comment (Ctrl+/)',
              onPressed: onComment,
            ),
            _buildToolbarButton(
              icon: Icons.auto_fix_high,
              tooltip: 'Format Code (Shift+Alt+F)',
              onPressed: onFormat,
            ),
          ]),

          const VerticalDivider(),

          // Run operations
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: isRunning ? Icons.stop : Icons.play_arrow,
              tooltip: isRunning ? 'Stop' : 'Run (F5)',
              onPressed: onRun,
              color: isRunning ? Colors.red : Colors.green,
            ),
            _buildToolbarButton(
              icon: Icons.bug_report,
              tooltip: 'Debug (F9)',
              onPressed: onDebug,
              color: Colors.orange,
            ),
          ]),

          const VerticalDivider(),

          // Language selector
          if (availableLanguages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: currentLanguage,
                hint: const Text('Language'),
                underline: const SizedBox(),
                items: availableLanguages.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => onLanguageChanged?.call(value ?? ''),
              ),
            ),

          const Spacer(),

          // Terminal and settings
          _buildToolbarGroup([
            _buildToolbarButton(
              icon: Icons.terminal,
              tooltip: 'Toggle Terminal (Ctrl+`)',
              onPressed: onTerminal,
            ),
            _buildToolbarButton(
              icon: Icons.settings,
              tooltip: 'Settings',
              onPressed: onSettings,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildToolbarGroup(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: buttons),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: color,
        splashRadius: 20,
      ),
    );
  }
}

class EditorStatusBar extends StatelessWidget {
  final String? currentFile;
  final int currentLine;
  final int currentColumn;
  final String? language;
  final String? encoding;
  final bool hasUnsavedChanges;
  final int? wordCount;
  final String? gitBranch;

  const EditorStatusBar({
    super.key,
    this.currentFile,
    this.currentLine = 1,
    this.currentColumn = 1,
    this.language,
    this.encoding = 'UTF-8',
    this.hasUnsavedChanges = false,
    this.wordCount,
    this.gitBranch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // File info
          if (currentFile != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currentFile!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  if (hasUnsavedChanges) ...[
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
            ),
            const VerticalDivider(),
          ],

          // Cursor position
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Ln $currentLine, Col $currentColumn',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),

          if (wordCount != null) ...[
            const VerticalDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$wordCount words',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
          ],

          const Spacer(),

          // Git branch
          if (gitBranch != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.source,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    gitBranch!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(),
          ],

          // Language
          if (language != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                language!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            const VerticalDivider(),
          ],

          // Encoding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              encoding!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
