// lib/services/editor_plugin_system.dart
import 'dart:async';
import 'package:flutter/material.dart';

abstract class EditorPlugin {
  String get name;
  String get version;
  String get description;
  List<String> get supportedLanguages;
  bool get isEnabled;

  Future<void> initialize();
  Future<void> dispose();

  // Plugin capabilities
  Widget? buildSidebarPanel(BuildContext context) => null;
  Widget? buildStatusBarWidget(BuildContext context) => null;
  List<EditorCommand> getCommands() => [];
  List<String> getSnippets(String language) => [];
  String? formatCode(String code, String language) => null;
  List<String> getCompletionSuggestions(
    String code,
    int cursorPosition,
    String language,
  ) => [];
}

class EditorCommand {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<String> keybindings;
  final VoidCallback action;

  EditorCommand({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.keybindings,
    required this.action,
  });
}

class EditorPluginSystem {
  static final EditorPluginSystem _instance = EditorPluginSystem._internal();
  factory EditorPluginSystem() => _instance;
  EditorPluginSystem._internal();

  final List<EditorPlugin> _plugins = [];
  final Map<String, EditorCommand> _commands = {};
  final StreamController<String> _eventController =
      StreamController.broadcast();

  Stream<String> get events => _eventController.stream;

  Future<void> initialize() async {
    // Load built-in plugins
    await _loadBuiltInPlugins();

    // Initialize all plugins
    for (final plugin in _plugins) {
      try {
        await plugin.initialize();
        _registerPluginCommands(plugin);
      } catch (e) {
        print('Failed to initialize plugin ${plugin.name}: $e');
      }
    }
  }

  Future<void> _loadBuiltInPlugins() async {
    // Add built-in plugins
    _plugins.addAll([
      DartFormatterPlugin(),
      GitIntegrationPlugin(),
      SnippetManagerPlugin(),
      ThemeManagerPlugin(),
      AutoSavePlugin(),
    ]);
  }

  void _registerPluginCommands(EditorPlugin plugin) {
    for (final command in plugin.getCommands()) {
      _commands[command.id] = command;
    }
  }

  void executeCommand(String commandId) {
    final command = _commands[commandId];
    if (command != null) {
      command.action();
      _eventController.add('command_executed:$commandId');
    }
  }

  List<EditorCommand> getAllCommands() {
    return _commands.values.toList();
  }

  List<String> getCompletionSuggestions(
    String code,
    int cursorPosition,
    String language,
  ) {
    final suggestions = <String>[];
    for (final plugin in _plugins.where(
      (p) => p.isEnabled && p.supportedLanguages.contains(language),
    )) {
      suggestions.addAll(
        plugin.getCompletionSuggestions(code, cursorPosition, language),
      );
    }
    return suggestions;
  }

  String? formatCode(String code, String language) {
    for (final plugin in _plugins.where(
      (p) => p.isEnabled && p.supportedLanguages.contains(language),
    )) {
      final formatted = plugin.formatCode(code, language);
      if (formatted != null) return formatted;
    }
    return null;
  }

  List<Widget> getSidebarPanels(BuildContext context) {
    return _plugins
        .where((p) => p.isEnabled)
        .map((p) => p.buildSidebarPanel(context))
        .where((w) => w != null)
        .cast<Widget>()
        .toList();
  }

  void dispose() {
    for (final plugin in _plugins) {
      plugin.dispose();
    }
    _eventController.close();
  }
}

// Built-in plugins

class DartFormatterPlugin extends EditorPlugin {
  @override
  String get name => 'Dart Formatter';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Formats Dart code using dart format';

  @override
  List<String> get supportedLanguages => ['dart'];

  @override
  bool get isEnabled => true;

  @override
  Future<void> initialize() async {
    // Initialize dart formatter
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }

  @override
  String? formatCode(String code, String language) {
    if (language != 'dart') return null;

    // Basic Dart formatting logic
    return code
        .replaceAll(RegExp(r'\{\s*\n\s*'), '{\n  ')
        .replaceAll(RegExp(r'\n\s*\}'), '\n}')
        .replaceAll(RegExp(r';\s*\n\s*'), ';\n  ');
  }

  @override
  List<EditorCommand> getCommands() {
    return [
      EditorCommand(
        id: 'dart.format',
        name: 'Format Dart Code',
        description: 'Formats the current Dart file',
        icon: Icons.auto_fix_high,
        keybindings: ['Shift+Alt+F'],
        action: () {
          // Format action will be implemented by the editor
        },
      ),
    ];
  }

  @override
  List<String> getCompletionSuggestions(
    String code,
    int cursorPosition,
    String language,
  ) {
    if (language != 'dart') return [];

    return [
      'StatelessWidget',
      'StatefulWidget',
      'BuildContext',
      'Widget',
      'Future',
      'async',
      'await',
      'setState',
      'initState',
      'dispose',
      'build',
    ];
  }
}

class GitIntegrationPlugin extends EditorPlugin {
  @override
  String get name => 'Git Integration';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Provides Git integration features';

  @override
  List<String> get supportedLanguages => ['*']; // All languages

  @override
  bool get isEnabled => true;

  @override
  Future<void> initialize() async {
    // Initialize Git integration
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }

  @override
  Widget buildSidebarPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Git', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildGitButton(context, 'Stage All', Icons.add, () {}),
          _buildGitButton(context, 'Commit', Icons.check, () {}),
          _buildGitButton(context, 'Push', Icons.cloud_upload, () {}),
          _buildGitButton(context, 'Pull', Icons.cloud_download, () {}),
        ],
      ),
    );
  }

  Widget _buildGitButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
        ),
      ),
    );
  }

  @override
  List<EditorCommand> getCommands() {
    return [
      EditorCommand(
        id: 'git.stage',
        name: 'Stage Changes',
        description: 'Stage all changes for commit',
        icon: Icons.add,
        keybindings: ['Ctrl+Shift+A'],
        action: () {},
      ),
      EditorCommand(
        id: 'git.commit',
        name: 'Commit',
        description: 'Commit staged changes',
        icon: Icons.check,
        keybindings: ['Ctrl+Shift+C'],
        action: () {},
      ),
    ];
  }
}

class SnippetManagerPlugin extends EditorPlugin {
  @override
  String get name => 'Snippet Manager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Manages code snippets';

  @override
  List<String> get supportedLanguages => ['dart', 'javascript', 'python'];

  @override
  bool get isEnabled => true;

  final Map<String, List<String>> _snippets = {
    'dart': [
      'class \${1:MyClass} {\n  \${2:// TODO: implement}\n}',
      'void \${1:methodName}() {\n  \${2:// TODO: implement}\n}',
      'if (\${1:condition}) {\n  \${2:// TODO: implement}\n}',
      'for (int i = 0; i < \${1:length}; i++) {\n  \${2:// TODO: implement}\n}',
    ],
    'javascript': [
      'function \${1:functionName}() {\n  \${2:// TODO: implement}\n}',
      'const \${1:variableName} = \${2:value};',
      'if (\${1:condition}) {\n  \${2:// TODO: implement}\n}',
      'for (let i = 0; i < \${1:length}; i++) {\n  \${2:// TODO: implement}\n}',
    ],
  };

  @override
  Future<void> initialize() async {
    // Initialize snippets
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }

  @override
  List<String> getSnippets(String language) {
    return _snippets[language] ?? [];
  }

  @override
  List<String> getCompletionSuggestions(
    String code,
    int cursorPosition,
    String language,
  ) {
    final snippets = getSnippets(language);
    return snippets.map((snippet) => snippet.split('\n')[0].trim()).toList();
  }
}

class ThemeManagerPlugin extends EditorPlugin {
  @override
  String get name => 'Theme Manager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Manages editor themes';

  @override
  List<String> get supportedLanguages => ['*'];

  @override
  bool get isEnabled => true;

  @override
  Future<void> initialize() async {
    // Initialize themes
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }

  @override
  Widget buildSidebarPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Themes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Dark Theme'),
            trailing: Switch(value: true, onChanged: (value) {}),
          ),
          ListTile(
            title: const Text('High Contrast'),
            trailing: Switch(value: false, onChanged: (value) {}),
          ),
        ],
      ),
    );
  }
}

class AutoSavePlugin extends EditorPlugin {
  @override
  String get name => 'Auto Save';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Automatically saves files';

  @override
  List<String> get supportedLanguages => ['*'];

  @override
  bool get isEnabled => true;

  Timer? _autoSaveTimer;

  @override
  Future<void> initialize() async {
    // Start auto-save timer
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      EditorPluginSystem()._eventController.add('auto_save_triggered');
    });
  }

  @override
  Future<void> dispose() async {
    _autoSaveTimer?.cancel();
  }

  @override
  List<EditorCommand> getCommands() {
    return [
      EditorCommand(
        id: 'autosave.toggle',
        name: 'Toggle Auto Save',
        description: 'Enable or disable auto save',
        icon: Icons.save,
        keybindings: [],
        action: () {},
      ),
    ];
  }

  @override
  Widget buildStatusBarWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            Icons.save,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'Auto',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
