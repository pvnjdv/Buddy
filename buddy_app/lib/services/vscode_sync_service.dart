import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/project_model.dart';
import '../models/flow_models.dart';
import 'flow_service.dart';
import 'vscode_integration_service.dart';

/// Service for synchronizing VS Code changes across all platforms
class VSCodeSyncService {
  static const String _githubApiUrl = 'https://api.github.com';
  static String? _githubToken;

  // Active sync sessions
  static final Map<String, SyncSession> _activeSessions = {};

  // Sync listeners
  static final Map<String, List<Function(ProjectFlow)>> _syncListeners = {};

  /// Initialize sync service
  static void initialize({required String githubToken}) {
    _githubToken = githubToken;
  }

  /// Start monitoring a VS Code session for changes
  static Future<void> startSyncSession(
    VSCodeSession vscodeSession,
    ProjectFlow project,
  ) async {
    final syncSession = SyncSession(
      sessionId: vscodeSession.sessionId!,
      projectId: project.id,
      vscodeSession: vscodeSession,
      project: project,
      lastSyncAt: DateTime.now(),
      isActive: true,
    );

    _activeSessions[project.id] = syncSession;

    // Start monitoring based on session type
    if (vscodeSession.sessionType == VSCodeSessionType.web ||
        vscodeSession.sessionType == VSCodeSessionType.mobileWebView) {
      _startGitHubRepoMonitoring(syncSession);
    } else if (vscodeSession.sessionType == VSCodeSessionType.desktop) {
      _startLocalFileMonitoring(syncSession);
    }
  }

  /// Stop sync session
  static Future<void> stopSyncSession(String projectId) async {
    final session = _activeSessions[projectId];
    if (session != null) {
      session.isActive = false;
      session.timer?.cancel();
      _activeSessions.remove(projectId);
    }
  }

  /// Add sync listener for project changes
  static void addSyncListener(
    String projectId,
    Function(ProjectFlow) listener,
  ) {
    if (!_syncListeners.containsKey(projectId)) {
      _syncListeners[projectId] = [];
    }
    _syncListeners[projectId]!.add(listener);
  }

  /// Remove sync listener
  static void removeSyncListener(
    String projectId,
    Function(ProjectFlow) listener,
  ) {
    _syncListeners[projectId]?.remove(listener);
  }

  /// Force sync now
  static Future<ProjectFlow?> forceSyncNow(String projectId) async {
    final session = _activeSessions[projectId];
    if (session == null) return null;

    return await _performSync(session);
  }

  /// Start monitoring GitHub repository for changes
  static void _startGitHubRepoMonitoring(SyncSession session) {
    // Poll every 30 seconds for changes
    session.timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!session.isActive) {
        timer.cancel();
        return;
      }

      try {
        await _performSync(session);
      } catch (e) {
        print('GitHub sync error for ${session.projectId}: $e');
      }
    });
  }

  /// Start monitoring local files for changes (desktop)
  static void _startLocalFileMonitoring(SyncSession session) {
    if (session.vscodeSession.localPath == null) return;

    // Poll local directory for changes
    session.timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!session.isActive) {
        timer.cancel();
        return;
      }

      try {
        await _syncLocalChanges(session);
      } catch (e) {
        print('Local sync error for ${session.projectId}: $e');
      }
    });
  }

  /// Perform sync with GitHub repository
  static Future<ProjectFlow?> _performSync(SyncSession session) async {
    if (_githubToken == null || session.vscodeSession.sessionId == null) {
      return null;
    }

    try {
      // Get latest commit information
      final repoFullName = session.vscodeSession.sessionId!;
      final commitsResponse = await http.get(
        Uri.parse('$_githubApiUrl/repos/$repoFullName/commits?per_page=1'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (commitsResponse.statusCode != 200) {
        return null;
      }

      final commits = jsonDecode(commitsResponse.body) as List;
      if (commits.isEmpty) return null;

      final latestCommit = commits.first;
      final commitDate = DateTime.parse(
        latestCommit['commit']['committer']['date'],
      );

      // Check if there are new changes since last sync
      if (commitDate.isAfter(session.lastSyncAt)) {
        print('New changes detected in ${session.projectId}');

        // Download updated files
        final updatedProject = await _downloadProjectChanges(
          session,
          repoFullName,
        );
        if (updatedProject != null) {
          session.lastSyncAt = DateTime.now();
          session.project = updatedProject;

          // Notify listeners
          _notifyListeners(session.projectId, updatedProject);

          return updatedProject;
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }

    return null;
  }

  /// Download and parse project changes from GitHub
  static Future<ProjectFlow?> _downloadProjectChanges(
    SyncSession session,
    String repoFullName,
  ) async {
    try {
      // Get repository contents
      final contentsResponse = await http.get(
        Uri.parse('$_githubApiUrl/repos/$repoFullName/contents'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (contentsResponse.statusCode != 200) {
        return null;
      }

      final contents = jsonDecode(contentsResponse.body) as List;

      // Look for project progress indicators in files
      final updatedProject = session.project.copyWith();
      bool hasChanges = false;

      // Check README.md for project updates
      final readmeFile = contents.firstWhere(
        (file) => file['name'] == 'README.md',
        orElse: () => null,
      );

      if (readmeFile != null) {
        final readmeContent = await _downloadFileContent(
          repoFullName,
          'README.md',
        );
        if (readmeContent != null) {
          // Parse README for checkpoint completion status
          final checkpointUpdates = _parseCheckpointStatus(readmeContent);
          if (checkpointUpdates.isNotEmpty) {
            // Update checkpoints based on README content
            for (int i = 0; i < updatedProject.checkpoints.length; i++) {
              final checkpoint = updatedProject.checkpoints[i];
              final isCompleted =
                  checkpointUpdates[checkpoint.title] ?? checkpoint.isCompleted;

              if (isCompleted != checkpoint.isCompleted) {
                updatedProject.checkpoints[i] = checkpoint.copyWith(
                  isCompleted: isCompleted,
                  completedAt: isCompleted ? DateTime.now() : null,
                );
                hasChanges = true;
              }
            }
          }
        }
      }

      // Update project timestamps
      if (hasChanges) {
        return updatedProject.copyWith(updatedAt: DateTime.now());
      }

      return null;
    } catch (e) {
      print('Error downloading project changes: $e');
      return null;
    }
  }

  /// Download file content from GitHub
  static Future<String?> _downloadFileContent(
    String repoFullName,
    String filePath,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_githubApiUrl/repos/$repoFullName/contents/$filePath'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final fileData = jsonDecode(response.body);
        final content = fileData['content'] as String;
        return utf8.decode(base64Decode(content.replaceAll('\n', '')));
      }
    } catch (e) {
      print('Error downloading file $filePath: $e');
    }

    return null;
  }

  /// Parse checkpoint completion status from README content
  static Map<String, bool> _parseCheckpointStatus(String readmeContent) {
    final checkpointStatus = <String, bool>{};
    final lines = readmeContent.split('\n');

    for (final line in lines) {
      // Look for checkbox patterns: ✅ or ⏳ followed by checkpoint title
      final checkboxMatch = RegExp(r'^- ([✅⏳]) (.+)$').firstMatch(line.trim());
      if (checkboxMatch != null) {
        final isCompleted = checkboxMatch.group(1) == '✅';
        final title = checkboxMatch.group(2)!.trim();
        checkpointStatus[title] = isCompleted;
      }
    }

    return checkpointStatus;
  }

  /// Sync local file changes (desktop)
  static Future<void> _syncLocalChanges(SyncSession session) async {
    if (session.vscodeSession.localPath == null) return;

    try {
      final projectDir = Directory(session.vscodeSession.localPath!);
      if (!await projectDir.exists()) return;

      // Check for file modifications
      final lastModified = await _getLastModifiedTime(projectDir);

      if (lastModified.isAfter(session.lastSyncAt)) {
        print('Local changes detected in ${session.projectId}');

        // Upload changes to GitHub if web session exists
        await _uploadLocalChangesToGitHub(session);

        session.lastSyncAt = DateTime.now();
      }
    } catch (e) {
      print('Local sync error: $e');
    }
  }

  /// Get last modified time of directory
  static Future<DateTime> _getLastModifiedTime(Directory directory) async {
    DateTime lastModified = DateTime.fromMillisecondsSinceEpoch(0);

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isAfter(lastModified)) {
          lastModified = stat.modified;
        }
      }
    }

    return lastModified;
  }

  /// Upload local changes to GitHub
  static Future<void> _uploadLocalChangesToGitHub(SyncSession session) async {
    if (session.vscodeSession.localPath == null || _githubToken == null) return;

    try {
      final projectDir = Directory(session.vscodeSession.localPath!);
      final repoFullName = session.vscodeSession.sessionId!;

      // Read all files and upload changes
      await for (final entity in projectDir.list(recursive: true)) {
        if (entity is File && !entity.path.contains('.git')) {
          final relativePath = entity.path.replaceFirst(
            '${projectDir.path}/',
            '',
          );
          final content = await entity.readAsString();

          // Notify backend about this file change
          await FlowService.sendCodeEvent(
            session.projectId,
            CodeEvent(path: relativePath, event: 'modified', editor: 'vscode'),
          );

          await _uploadFileToGitHub(repoFullName, relativePath, content);
        }
      }
    } catch (e) {
      print('Error uploading local changes: $e');
    }
  }

  /// Upload file to GitHub
  static Future<void> _uploadFileToGitHub(
    String repoFullName,
    String filePath,
    String content,
  ) async {
    final encodedContent = base64Encode(utf8.encode(content));

    // Get current file SHA if it exists
    String? sha;
    try {
      final existingResponse = await http.get(
        Uri.parse('$_githubApiUrl/repos/$repoFullName/contents/$filePath'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (existingResponse.statusCode == 200) {
        final existingData = jsonDecode(existingResponse.body);
        sha = existingData['sha'];
      }
    } catch (e) {
      // File doesn't exist, that's okay
    }

    final body = <String, dynamic>{
      'message': 'Update $filePath from VS Code',
      'content': encodedContent,
      'branch': 'main',
    };

    if (sha != null) {
      body['sha'] = sha;
    }

    final response = await http.put(
      Uri.parse('$_githubApiUrl/repos/$repoFullName/contents/$filePath'),
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('Failed to upload $filePath: ${response.statusCode}');
    }
  }

  /// Notify all listeners of project changes
  static void _notifyListeners(String projectId, ProjectFlow updatedProject) {
    final listeners = _syncListeners[projectId];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(updatedProject);
        } catch (e) {
          print('Error notifying listener: $e');
        }
      }
    }
  }

  /// Get sync status for project
  static SyncStatus getSyncStatus(String projectId) {
    final session = _activeSessions[projectId];
    if (session == null) {
      return SyncStatus.notSyncing;
    }

    final timeSinceLastSync = DateTime.now().difference(session.lastSyncAt);

    if (timeSinceLastSync.inMinutes < 2) {
      return SyncStatus.synced;
    } else if (timeSinceLastSync.inMinutes < 10) {
      return SyncStatus.syncing;
    } else {
      return SyncStatus.outdated;
    }
  }

  /// Get all active sync sessions
  static List<SyncSession> getActiveSessions() {
    return _activeSessions.values.where((s) => s.isActive).toList();
  }

  /// Cleanup all sessions
  static Future<void> cleanup() async {
    for (final session in _activeSessions.values) {
      session.timer?.cancel();
    }
    _activeSessions.clear();
    _syncListeners.clear();
  }
}

/// Sync session information
class SyncSession {
  final String sessionId;
  final String projectId;
  final VSCodeSession vscodeSession;
  ProjectFlow project;
  DateTime lastSyncAt;
  bool isActive;
  Timer? timer;

  SyncSession({
    required this.sessionId,
    required this.projectId,
    required this.vscodeSession,
    required this.project,
    required this.lastSyncAt,
    required this.isActive,
    this.timer,
  });
}

/// Sync status enum
enum SyncStatus {
  notSyncing, // No active sync
  syncing, // Currently syncing
  synced, // Recently synced
  outdated, // Needs sync
  error, // Sync error
}

/// Sync event for notifications
class SyncEvent {
  final String projectId;
  final SyncEventType type;
  final String message;
  final DateTime timestamp;
  final ProjectFlow? updatedProject;

  SyncEvent({
    required this.projectId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.updatedProject,
  });
}

/// Sync event types
enum SyncEventType {
  syncStarted,
  syncCompleted,
  syncFailed,
  changesDetected,
  projectUpdated,
}
