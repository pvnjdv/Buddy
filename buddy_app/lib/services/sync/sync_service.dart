// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:path/path.dart' as path;
import '../../models/code_editor_models.dart';
import '../../config/api_config.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final StreamController<CodeFile> _fileChangedController =
      StreamController.broadcast();
  final StreamController<CodeProject> _projectChangedController =
      StreamController.broadcast();
  final StreamController<String> _syncStatusController =
      StreamController.broadcast();

  Stream<CodeFile> get onFileChanged => _fileChangedController.stream;
  Stream<CodeProject> get onProjectChanged => _projectChangedController.stream;
  Stream<String> get onSyncStatus => _syncStatusController.stream;

  WebSocketChannel? _vsCodeChannel;
  WebSocketChannel? _buddyServerChannel;
  Timer? _syncTimer;

  SyncConfig _config = SyncConfig();
  bool _isSyncing = false;
  String? _currentProjectPath;

  final Map<String, DateTime> _fileTimestamps = {};

  Future<void> initialize({SyncConfig? config}) async {
    if (config != null) {
      _config = config;
    }

    _syncStatusController.add('Initializing sync service...');

    try {
      // Connect to Buddy backend
      await _connectToBuddyServer();

      // Try to detect and connect to VS Code
      if (_config.enabled) {
        await _detectAndConnectToVSCode();
      }

      // Start sync timer
      _startSyncTimer();

      _syncStatusController.add('Sync service initialized');
    } catch (e) {
      _syncStatusController.add('Failed to initialize sync service: $e');
    }
  }

  // Enhanced VS Code integration
  Future<void> notifyVSCodeFileChange(
    String filePath,
    String changeType,
  ) async {
    if (!_isVSCodeConnected()) return;

    try {
      final message = {
        'type': 'fileChange',
        'data': {
          'filePath': filePath,
          'changeType': changeType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      _vsCodeChannel?.sink.add(jsonEncode(message));
      _syncStatusController.add(
        'Notified VS Code: $changeType ${path.basename(filePath)}',
      );
    } catch (e) {
      _syncStatusController.add('Failed to notify VS Code: $e');
    }
  }

  Future<void> openFileInVSCode(String filePath) async {
    if (!_isVSCodeConnected()) {
      // Try to detect and connect first
      await _detectAndConnectToVSCode();
    }

    if (!_isVSCodeConnected()) {
      _syncStatusController.add('VS Code not connected');
      return;
    }

    try {
      final message = {
        'type': 'openFile',
        'data': {'filePath': filePath, 'line': 1, 'column': 1},
      };

      _vsCodeChannel?.sink.add(jsonEncode(message));
      _syncStatusController.add(
        'Opened in VS Code: ${path.basename(filePath)}',
      );
    } catch (e) {
      _syncStatusController.add('Failed to open file in VS Code: $e');
    }
  }

  Future<void> syncProjectStructureWithVSCode() async {
    if (!_isVSCodeConnected() || _currentProjectPath == null) return;

    try {
      final message = {
        'type': 'projectStructure',
        'data': {
          'projectPath': _currentProjectPath,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      _vsCodeChannel?.sink.add(jsonEncode(message));
      _syncStatusController.add('Synced project structure with VS Code');
    } catch (e) {
      _syncStatusController.add('Failed to sync project structure: $e');
    }
  }

  Future<void> requestVSCodeWorkspaceOpen(String projectPath) async {
    if (!_isVSCodeConnected()) {
      await _detectAndConnectToVSCode();
    }

    if (!_isVSCodeConnected()) {
      _syncStatusController.add('VS Code not connected');
      return;
    }

    try {
      final message = {
        'type': 'openWorkspace',
        'data': {'workspacePath': projectPath},
      };

      _vsCodeChannel?.sink.add(jsonEncode(message));
      _syncStatusController.add('Requested VS Code to open workspace');
    } catch (e) {
      _syncStatusController.add('Failed to request workspace open: $e');
    }
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _vsCodeChannel?.sink.close();
    await _buddyServerChannel?.sink.close();
    _fileChangedController.close();
    _projectChangedController.close();
    _syncStatusController.close();
  }

  // Project sync
  Future<void> syncProject(CodeProject project) async {
    _currentProjectPath = project.path;
    _syncStatusController.add('Syncing project: ${project.name}');

    try {
      // Sync with VS Code
      if (_isVSCodeConnected()) {
        await _syncProjectWithVSCode(project);
      }

      // Sync with Buddy server
      await _syncProjectWithServer(project);

      // Watch for file changes
      _watchProjectFiles(project.path);

      _syncStatusController.add('Project synced successfully');
    } catch (e) {
      _syncStatusController.add('Project sync failed: $e');
      rethrow;
    }
  }

  // File sync
  Future<void> syncFile(CodeFile file) async {
    if (!_config.enabled || _isSyncing) return;

    _isSyncing = true;
    _syncStatusController.add('Syncing file: ${file.name}');

    try {
      // Update file timestamp
      _fileTimestamps[file.path] = DateTime.now();

      // Sync with VS Code
      if (_isVSCodeConnected()) {
        await _syncFileWithVSCode(file);
      }

      // Sync with Buddy server
      await _syncFileWithServer(file);

      _fileChangedController.add(file);
      _syncStatusController.add('File synced: ${file.name}');
    } catch (e) {
      _syncStatusController.add('File sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // VS Code Integration
  Future<void> _detectAndConnectToVSCode() async {
    try {
      // Try to detect VS Code installation
      final vsCodePaths = await _getVSCodePaths();

      for (final vsCodePath in vsCodePaths) {
        if (await File(vsCodePath).exists()) {
          _config = _config.copyWith(vsCodePath: vsCodePath);
          break;
        }
      }

      // Try to connect to VS Code extension
      await _connectToVSCodeExtension();
    } catch (e) {
      _syncStatusController.add('VS Code detection failed: $e');
    }
  }

  Future<List<String>> _getVSCodePaths() async {
    if (Platform.isWindows) {
      return [
        'C:\\Program Files\\Microsoft VS Code\\Code.exe',
        'C:\\Program Files (x86)\\Microsoft VS Code\\Code.exe',
        '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Programs\\Microsoft VS Code\\Code.exe',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code',
        '/usr/local/bin/code',
      ];
    } else {
      return [
        '/usr/bin/code',
        '/usr/local/bin/code',
        '/snap/bin/code',
        '${Platform.environment['HOME']}/.local/bin/code',
      ];
    }
  }

  Future<void> _connectToVSCodeExtension() async {
    try {
      // Try to connect to Buddy VS Code extension via WebSocket
      final uri = Uri.parse('ws://localhost:8765/vscode');
      _vsCodeChannel = IOWebSocketChannel.connect(uri);

      _vsCodeChannel!.stream.listen(
        _handleVSCodeMessage,
        onError: (error) {
          _syncStatusController.add('VS Code connection error: $error');
          _vsCodeChannel = null;
        },
        onDone: () {
          _syncStatusController.add('VS Code connection closed');
          _vsCodeChannel = null;
        },
      );

      // Send initial handshake
      _sendToVSCode({
        'type': 'handshake',
        'source': 'buddy_mobile',
        'version': '1.0.0',
      });

      _syncStatusController.add('Connected to VS Code');
    } catch (e) {
      _syncStatusController.add('Failed to connect to VS Code: $e');
    }
  }

  Future<void> _connectToBuddyServer() async {
    try {
      final uri = Uri.parse('${ApiConfig.wsBaseUrl}/sync');
      _buddyServerChannel = IOWebSocketChannel.connect(uri);

      _buddyServerChannel!.stream.listen(
        _handleBuddyServerMessage,
        onError: (error) {
          _syncStatusController.add('Buddy server connection error: $error');
          _buddyServerChannel = null;
        },
        onDone: () {
          _syncStatusController.add('Buddy server connection closed');
          _buddyServerChannel = null;
        },
      );

      _syncStatusController.add('Connected to Buddy server');
    } catch (e) {
      _syncStatusController.add('Failed to connect to Buddy server: $e');
    }
  }

  void _handleVSCodeMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'file_changed':
          _handleVSCodeFileChanged(data);
          break;
        case 'project_opened':
          _handleVSCodeProjectOpened(data);
          break;
        case 'settings_changed':
          _handleVSCodeSettingsChanged(data);
          break;
        case 'extension_installed':
          _handleVSCodeExtensionInstalled(data);
          break;
        default:
          _syncStatusController.add('Unknown VS Code message: ${data['type']}');
      }
    } catch (e) {
      _syncStatusController.add('Error handling VS Code message: $e');
    }
  }

  void _handleBuddyServerMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'file_sync':
          _handleServerFileSync(data);
          break;
        case 'project_sync':
          _handleServerProjectSync(data);
          break;
        case 'sync_status':
          _handleServerSyncStatus(data);
          break;
        default:
          _syncStatusController.add('Unknown server message: ${data['type']}');
      }
    } catch (e) {
      _syncStatusController.add('Error handling server message: $e');
    }
  }

  void _handleVSCodeFileChanged(Map<String, dynamic> data) {
    final filePath = data['filePath'] as String;
    final content = data['content'] as String;
    final lastModified =
        DateTime.tryParse(data['lastModified'] ?? '') ?? DateTime.now();

    // Check if we should update this file
    final ourTimestamp = _fileTimestamps[filePath];
    if (ourTimestamp != null && lastModified.isBefore(ourTimestamp)) {
      return; // Our change is newer
    }

    final file = CodeFile(
      path: filePath,
      name: path.basename(filePath),
      language: _detectLanguage(filePath),
      content: content,
      lastModified: lastModified,
    );

    _fileChangedController.add(file);
    _syncStatusController.add('File updated from VS Code: ${file.name}');
  }

  void _handleVSCodeProjectOpened(Map<String, dynamic> data) {
    final projectPath = data['projectPath'] as String;
    final projectName = data['projectName'] as String;

    // Create project representation
    final project = CodeProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: projectName,
      path: projectPath,
      type: 'vscode',
      language: 'mixed',
      mainFile: '',
      isRemote: true,
    );

    _projectChangedController.add(project);
    _syncStatusController.add('Project opened in VS Code: $projectName');
  }

  void _handleVSCodeSettingsChanged(Map<String, dynamic> data) {
    final settings = data['settings'] as Map<String, dynamic>;

    // Update sync configuration based on VS Code settings
    if (settings.containsKey('buddy.sync.enabled')) {
      _config = _config.copyWith(enabled: settings['buddy.sync.enabled']);
    }

    if (settings.containsKey('buddy.sync.autoSync')) {
      _config = _config.copyWith(autoSync: settings['buddy.sync.autoSync']);
    }

    _syncStatusController.add('VS Code settings updated');
  }

  void _handleVSCodeExtensionInstalled(Map<String, dynamic> data) {
    final extensions = List<String>.from(data['extensions'] ?? []);
    _config = _config.copyWith(syncExtensions: extensions);
    _syncStatusController.add('VS Code extensions synced');
  }

  void _handleServerFileSync(Map<String, dynamic> data) {
    // Handle file sync from server
    final file = CodeFile.fromJson(data['file']);
    _fileChangedController.add(file);
  }

  void _handleServerProjectSync(Map<String, dynamic> data) {
    // Handle project sync from server
    final project = CodeProject.fromJson(data['project']);
    _projectChangedController.add(project);
  }

  void _handleServerSyncStatus(Map<String, dynamic> data) {
    final status = data['status'] as String;
    _syncStatusController.add('Server: $status');
  }

  Future<void> _syncProjectWithVSCode(CodeProject project) async {
    if (!_isVSCodeConnected()) return;

    _sendToVSCode({'type': 'open_project', 'project': project.toJson()});
  }

  Future<void> _syncFileWithVSCode(CodeFile file) async {
    if (!_isVSCodeConnected()) return;

    _sendToVSCode({'type': 'update_file', 'file': file.toJson()});
  }

  Future<void> _syncProjectWithServer(CodeProject project) async {
    if (_buddyServerChannel == null) return;

    _sendToBuddyServer({'type': 'sync_project', 'project': project.toJson()});
  }

  Future<void> _syncFileWithServer(CodeFile file) async {
    if (_buddyServerChannel == null) return;

    _sendToBuddyServer({'type': 'sync_file', 'file': file.toJson()});
  }

  void _sendToVSCode(Map<String, dynamic> message) {
    if (_vsCodeChannel != null) {
      _vsCodeChannel!.sink.add(jsonEncode(message));
    }
  }

  void _sendToBuddyServer(Map<String, dynamic> message) {
    if (_buddyServerChannel != null) {
      _buddyServerChannel!.sink.add(jsonEncode(message));
    }
  }

  bool _isVSCodeConnected() {
    return _vsCodeChannel != null;
  }

  bool _isBuddyServerConnected() {
    return _buddyServerChannel != null;
  }

  void _startSyncTimer() {
    if (!_config.autoSync) return;

    _syncTimer = Timer.periodic(
      Duration(seconds: _config.syncInterval),
      (_) => _performPeriodicSync(),
    );
  }

  Future<void> _performPeriodicSync() async {
    if (_isSyncing || _currentProjectPath == null) return;

    try {
      await _checkForFileChanges(_currentProjectPath!);
    } catch (e) {
      _syncStatusController.add('Periodic sync error: $e');
    }
  }

  Future<void> _checkForFileChanges(String projectPath) async {
    final projectDir = Directory(projectPath);
    if (!await projectDir.exists()) return;

    await for (final entity in projectDir.list(recursive: true)) {
      if (entity is File) {
        final filePath = entity.path;

        // Skip certain files
        if (_shouldSkipFile(filePath)) continue;

        try {
          final stat = await entity.stat();
          final lastKnown = _fileTimestamps[filePath];

          if (lastKnown == null || stat.modified.isAfter(lastKnown)) {
            // File has changed
            final content = await entity.readAsString();
            final file = CodeFile(
              path: filePath,
              name: path.basename(filePath),
              language: _detectLanguage(filePath),
              content: content,
              lastModified: stat.modified,
              isModified: true,
            );

            await syncFile(file);
          }
        } catch (e) {
          // Skip files that can't be read
          continue;
        }
      }
    }
  }

  void _watchProjectFiles(String projectPath) {
    // Implement file system watcher for real-time sync
    // This would use dart:io's FileSystemEntity.watch() for real-time monitoring
  }

  bool _shouldSkipFile(String filePath) {
    final skipPatterns = [
      '.git/',
      'node_modules/',
      '.dart_tool/',
      'build/',
      '.buddy/',
      '.vscode/',
      '.idea/',
    ];

    return skipPatterns.any((pattern) => filePath.contains(pattern));
  }

  String _detectLanguage(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.dart':
        return 'dart';
      case '.py':
        return 'python';
      case '.js':
        return 'javascript';
      case '.ts':
        return 'typescript';
      case '.java':
        return 'java';
      case '.kt':
        return 'kotlin';
      case '.swift':
        return 'swift';
      case '.yaml':
      case '.yml':
        return 'yaml';
      case '.json':
        return 'json';
      case '.md':
        return 'markdown';
      default:
        return 'text';
    }
  }

  // Real-time collaboration features
  Future<void> startCollaboration(String sessionId) async {
    try {
      _sendToBuddyServer({
        'type': 'start_collaboration',
        'sessionId': sessionId,
        'projectPath': _currentProjectPath,
      });

      _syncStatusController.add('Started collaboration session: $sessionId');
    } catch (e) {
      _syncStatusController.add('Failed to start collaboration: $e');
    }
  }

  Future<void> stopCollaboration() async {
    try {
      _sendToBuddyServer({'type': 'stop_collaboration'});

      _syncStatusController.add('Stopped collaboration session');
    } catch (e) {
      _syncStatusController.add('Failed to stop collaboration: $e');
    }
  }

  Future<void> inviteCollaborator(String email) async {
    try {
      _sendToBuddyServer({
        'type': 'invite_collaborator',
        'email': email,
        'projectPath': _currentProjectPath,
      });

      _syncStatusController.add('Invited collaborator: $email');
    } catch (e) {
      _syncStatusController.add('Failed to invite collaborator: $e');
    }
  }

  // Settings sync
  Future<void> syncVSCodeSettings() async {
    try {
      if (!_isVSCodeConnected()) {
        throw Exception('Not connected to VS Code');
      }

      _sendToVSCode({'type': 'get_settings'});

      _syncStatusController.add('Requested VS Code settings sync');
    } catch (e) {
      _syncStatusController.add('Settings sync failed: $e');
    }
  }

  Future<void> syncVSCodeExtensions() async {
    try {
      if (!_isVSCodeConnected()) {
        throw Exception('Not connected to VS Code');
      }

      _sendToVSCode({'type': 'get_extensions'});

      _syncStatusController.add('Requested VS Code extensions sync');
    } catch (e) {
      _syncStatusController.add('Extensions sync failed: $e');
    }
  }

  // Configuration
  SyncConfig get config => _config;

  Future<void> updateConfig(SyncConfig newConfig) async {
    final oldConfig = _config;
    _config = newConfig;

    // Restart connections if needed
    if (oldConfig.enabled != newConfig.enabled) {
      if (newConfig.enabled) {
        await _detectAndConnectToVSCode();
      } else {
        await _vsCodeChannel?.sink.close();
        _vsCodeChannel = null;
      }
    }

    // Restart timer if interval changed
    if (oldConfig.syncInterval != newConfig.syncInterval ||
        oldConfig.autoSync != newConfig.autoSync) {
      _syncTimer?.cancel();
      _startSyncTimer();
    }

    _syncStatusController.add('Sync configuration updated');
  }

  // Status information
  bool get isConnected => _isVSCodeConnected() || _isBuddyServerConnected();
  bool get isVSCodeConnected => _isVSCodeConnected();
  bool get isBuddyServerConnected => _isBuddyServerConnected();
  bool get isSyncing => _isSyncing;
}

// Extension methods for SyncConfig
extension SyncConfigExtension on SyncConfig {
  SyncConfig copyWith({
    bool? enabled,
    String? vsCodePath,
    List<String>? syncExtensions,
    Map<String, dynamic>? settings,
    bool? autoSync,
    int? syncInterval,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      vsCodePath: vsCodePath ?? this.vsCodePath,
      syncExtensions: syncExtensions ?? this.syncExtensions,
      settings: settings ?? this.settings,
      autoSync: autoSync ?? this.autoSync,
      syncInterval: syncInterval ?? this.syncInterval,
    );
  }
}
