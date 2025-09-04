// lib/screens/dock/buddy_terminal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/dock_models.dart';
import '../../models/terminal_models.dart';
import '../../services/dock_service.dart';
import '../../services/terminal_service.dart';
import '../../config/settings/theme_config.dart';

class BuddyTerminalScreen extends StatefulWidget {
  final Device device;
  final bool isLocalTerminal;

  const BuddyTerminalScreen({
    super.key,
    required this.device,
    this.isLocalTerminal = false,
  });

  @override
  State<BuddyTerminalScreen> createState() => _BuddyTerminalScreenState();
}

class _BuddyTerminalScreenState extends State<BuddyTerminalScreen>
    with TickerProviderStateMixin {
  final DockService _dockService = DockService();
  final TerminalService _terminalService = TerminalService();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();
  final FocusNode _commandFocusNode = FocusNode();

  late TabController _tabController;
  List<TerminalSession> _sessions = [];
  int _currentSessionIndex = 0;
  List<String> _commandHistory = [];
  int _historyIndex = -1;
  bool _isConnected = false;
  bool _isExecuting = false;

  // Terminal state
  String _currentDirectory = '~';
  Map<String, String> _environmentVariables = {};
  List<TerminalCommand> _automationCommands = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _initializeTerminal();
    _loadAutomationCommands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commandController.dispose();
    _outputScrollController.dispose();
    _commandFocusNode.dispose();
    _terminalService.disconnect();
    super.dispose();
  }

  Future<void> _initializeTerminal() async {
    try {
      setState(() => _isConnected = false);

      // Create initial terminal session
      final session = TerminalSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceId: widget.device.id,
        name: widget.isLocalTerminal ? 'Local Terminal' : widget.device.name,
        isActive: true,
        workingDirectory: _currentDirectory,
      );

      _sessions.add(session);

      // Connect to device terminal
      if (widget.isLocalTerminal) {
        await _terminalService.connectLocal();
      } else {
        await _terminalService.connectRemote(widget.device);
      }

      setState(() => _isConnected = true);

      // Send initial commands to set up environment
      await _initializeSession(session);
    } catch (e) {
      _addOutput('❌ Failed to connect to terminal: $e', isError: true);
    }
  }

  Future<void> _initializeSession(TerminalSession session) async {
    // Get current directory
    await _executeCommand('pwd', silent: true);

    // Get environment variables
    await _executeCommand('env', silent: true);

    // Welcome message
    _addOutput('🚀 Buddy Terminal Connected to ${widget.device.name}');
    _addOutput('📁 Working Directory: $_currentDirectory');
    _addOutput('💡 Type "help" for available commands or use automation panel');
    _addOutput('');
  }

  Future<void> _loadAutomationCommands() async {
    // Load predefined automation commands based on device platform
    _automationCommands = _getAutomationCommandsForPlatform(
      widget.device.platform,
    );
    setState(() {});
  }

  List<TerminalCommand> _getAutomationCommandsForPlatform(String platform) {
    final baseCommands = [
      TerminalCommand(
        id: 'system_info',
        name: 'System Information',
        description: 'Get detailed system information',
        command: _getSystemInfoCommand(platform),
        category: 'System',
        icon: Icons.info_outline,
      ),
      TerminalCommand(
        id: 'disk_usage',
        name: 'Disk Usage',
        description: 'Check disk space usage',
        command: platform.toLowerCase().contains('windows') ? 'dir' : 'df -h',
        category: 'System',
        icon: Icons.storage,
      ),
      TerminalCommand(
        id: 'running_processes',
        name: 'Running Processes',
        description: 'List running processes',
        command: platform.toLowerCase().contains('windows')
            ? 'tasklist'
            : 'ps aux',
        category: 'System',
        icon: Icons.list_alt,
      ),
      TerminalCommand(
        id: 'network_status',
        name: 'Network Status',
        description: 'Check network connectivity',
        command: 'ping -c 4 8.8.8.8',
        category: 'Network',
        icon: Icons.network_check,
      ),
      TerminalCommand(
        id: 'update_system',
        name: 'Update System',
        description: 'Update system packages',
        command: _getUpdateCommand(platform),
        category: 'Maintenance',
        icon: Icons.system_update,
        requiresConfirmation: true,
      ),
    ];

    // Add platform-specific commands
    if (platform.toLowerCase().contains('android')) {
      baseCommands.addAll([
        TerminalCommand(
          id: 'battery_info',
          name: 'Battery Information',
          description: 'Get battery status',
          command: 'dumpsys battery',
          category: 'Mobile',
          icon: Icons.battery_full,
        ),
        TerminalCommand(
          id: 'installed_apps',
          name: 'Installed Apps',
          description: 'List installed applications',
          command: 'pm list packages',
          category: 'Mobile',
          icon: Icons.apps,
        ),
      ]);
    }

    return baseCommands;
  }

  String _getSystemInfoCommand(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'systeminfo';
      case 'linux':
      case 'android':
        return 'uname -a && cat /proc/version';
      case 'macos':
        return 'system_profiler SPSoftwareDataType';
      default:
        return 'uname -a';
    }
  }

  String _getUpdateCommand(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'winget upgrade --all';
      case 'linux':
        return 'sudo apt update && sudo apt upgrade';
      case 'macos':
        return 'brew update && brew upgrade';
      case 'android':
        return 'am broadcast -a android.intent.action.MY_PACKAGE_REPLACED';
      default:
        return 'echo "Update command not available for this platform"';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Buddy Terminal - ${widget.device.name}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        bottom: _sessions.length > 1
            ? TabBar(
                controller: _tabController,
                tabs: _sessions
                    .map((session) => Tab(text: session.name))
                    .toList(),
                onTap: (index) {
                  setState(() => _currentSessionIndex = index);
                },
              )
            : null,
        actions: [
          IconButton(
            onPressed: _showAutomationPanel,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Automation Commands',
          ),
          IconButton(
            onPressed: _addNewSession,
            icon: const Icon(Icons.add),
            tooltip: 'New Session',
          ),
          IconButton(
            onPressed: _showTerminalSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Terminal Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Text(
                '🔄 Connecting to terminal...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),

          // Terminal output
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _outputScrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _getCurrentSession().output.length,
                itemBuilder: (context, index) {
                  final output = _getCurrentSession().output[index];
                  return _buildOutputLine(output);
                },
              ),
            ),
          ),

          // Command input area
          _buildCommandInput(),
        ],
      ),
    );
  }

  Widget _buildOutputLine(TerminalOutput output) {
    Color textColor = Colors.white;
    if (output.isError) textColor = Colors.red;
    if (output.isSuccess) textColor = Colors.green;
    if (output.isWarning) textColor = Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        output.text,
        style: TextStyle(fontFamily: 'Courier', fontSize: 14, color: textColor),
      ),
    );
  }

  Widget _buildCommandInput() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Current directory indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _currentDirectory,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Command input
          Expanded(
            child: TextField(
              controller: _commandController,
              focusNode: _commandFocusNode,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Courier',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter command...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                prefixText: '> ',
                prefixStyle: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onSubmitted: (command) => _executeCommand(command),
              onChanged: _handleCommandInput,
            ),
          ),

          // Execute button
          IconButton(
            onPressed: _isExecuting
                ? null
                : () => _executeCommand(_commandController.text),
            icon: _isExecuting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'Execute Command',
          ),
        ],
      ),
    );
  }

  void _handleCommandInput(String value) {
    // Handle command suggestions, auto-completion, etc.
  }

  TerminalSession _getCurrentSession() {
    if (_sessions.isEmpty) {
      return TerminalSession(
        id: 'default',
        deviceId: widget.device.id,
        name: 'Default',
        isActive: true,
        workingDirectory: '~',
      );
    }
    return _sessions[_currentSessionIndex];
  }

  Future<void> _executeCommand(String command, {bool silent = false}) async {
    if (command.trim().isEmpty) return;

    setState(() => _isExecuting = true);

    try {
      // Add command to history
      if (!silent) {
        _commandHistory.add(command);
        _addOutput('> $command', isCommand: true);
      }

      // Handle built-in commands
      if (await _handleBuiltInCommand(command)) {
        return;
      }

      // Execute command on device
      final result = await _terminalService.executeCommand(
        widget.device.id,
        command,
        workingDirectory: _currentDirectory,
      );

      // Process result
      if (result.success) {
        if (result.output.isNotEmpty && !silent) {
          _addOutput(result.output);
        }

        // Update working directory if command was 'cd'
        if (command.startsWith('cd ')) {
          _currentDirectory = result.workingDirectory ?? _currentDirectory;
        }
      } else {
        _addOutput(result.error ?? 'Command failed', isError: true);
      }
    } catch (e) {
      _addOutput('Error executing command: $e', isError: true);
    } finally {
      setState(() => _isExecuting = false);
      _commandController.clear();
      _scrollToBottom();
    }
  }

  Future<bool> _handleBuiltInCommand(String command) async {
    final parts = command.trim().split(' ');
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'help':
        _showHelp();
        return true;
      case 'clear':
        _getCurrentSession().output.clear();
        setState(() {});
        return true;
      case 'history':
        _showCommandHistory();
        return true;
      case 'automation':
        _showAutomationPanel();
        return true;
      case 'sessions':
        _showSessionInfo();
        return true;
      default:
        return false;
    }
  }

  void _showHelp() {
    _addOutput('📖 Buddy Terminal Help');
    _addOutput('');
    _addOutput('Built-in Commands:');
    _addOutput('  help       - Show this help message');
    _addOutput('  clear      - Clear terminal output');
    _addOutput('  history    - Show command history');
    _addOutput('  automation - Open automation panel');
    _addOutput('  sessions   - Show session information');
    _addOutput('');
    _addOutput('Features:');
    _addOutput('  • Use ↑/↓ arrows to navigate command history');
    _addOutput('  • Tap automation button for predefined commands');
    _addOutput('  • Create multiple terminal sessions');
    _addOutput('  • Cross-platform command execution');
    _addOutput('');
  }

  void _showCommandHistory() {
    _addOutput('📜 Command History:');
    for (int i = 0; i < _commandHistory.length; i++) {
      _addOutput('  ${i + 1}. ${_commandHistory[i]}');
    }
    _addOutput('');
  }

  void _showSessionInfo() {
    _addOutput('📊 Session Information:');
    for (int i = 0; i < _sessions.length; i++) {
      final session = _sessions[i];
      final status = i == _currentSessionIndex ? '(current)' : '';
      _addOutput('  ${i + 1}. ${session.name} $status');
      _addOutput('     Working Directory: ${session.workingDirectory}');
      _addOutput(
        '     Commands Executed: ${session.output.where((o) => o.isCommand).length}',
      );
    }
    _addOutput('');
  }

  void _addOutput(
    String text, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
    bool isCommand = false,
  }) {
    final output = TerminalOutput(
      text: text,
      timestamp: DateTime.now(),
      isError: isError,
      isSuccess: isSuccess,
      isWarning: isWarning,
      isCommand: isCommand,
    );

    _getCurrentSession().output.add(output);
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAutomationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) =>
            _buildAutomationPanel(scrollController),
      ),
    );
  }

  Widget _buildAutomationPanel(ScrollController scrollController) {
    final categories = _automationCommands
        .map((cmd) => cmd.category)
        .toSet()
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🤖 Automation Commands',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final commands = _automationCommands
                    .where((cmd) => cmd.category == category)
                    .toList();

                return _buildAutomationCategory(category, commands);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCategory(
    String category,
    List<TerminalCommand> commands,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(category),
        children: commands
            .map((command) => _buildAutomationCommand(command))
            .toList(),
      ),
    );
  }

  Widget _buildAutomationCommand(TerminalCommand command) {
    return ListTile(
      leading: Icon(command.icon),
      title: Text(command.name),
      subtitle: Text(command.description),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () {
          Navigator.pop(context);
          if (command.requiresConfirmation) {
            _showCommandConfirmation(command);
          } else {
            _executeCommand(command.command);
          }
        },
      ),
      onTap: () {
        _commandController.text = command.command;
        Navigator.pop(context);
        _commandFocusNode.requestFocus();
      },
    );
  }

  void _showCommandConfirmation(TerminalCommand command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(command.description),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                command.command,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This command may make system changes. Continue?',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeCommand(command.command);
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  void _addNewSession() {
    final session = TerminalSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: widget.device.id,
      name: 'Session ${_sessions.length + 1}',
      isActive: true,
      workingDirectory: _currentDirectory,
    );

    setState(() {
      _sessions.add(session);
      _currentSessionIndex = _sessions.length - 1;
      _tabController = TabController(length: _sessions.length, vsync: this);
      _tabController.index = _currentSessionIndex;
    });

    _addOutput('📱 New terminal session created');
  }

  void _showTerminalSettings() {
    // Show terminal settings dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminal Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Terminal settings coming soon...'),
            // Add settings like font size, color scheme, etc.
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
