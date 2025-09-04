// lib/services/terminal_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/dock_models.dart';
import '../models/terminal_models.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class TerminalService {
  static final TerminalService _instance = TerminalService._internal();
  factory TerminalService() => _instance;
  TerminalService._internal();

  WebSocketChannel? _webSocketChannel;
  Map<String, TerminalSession> _activeSessions = {};
  StreamController<TerminalOutput>? _outputController;
  StreamController<TerminalSession>? _sessionController;

  Stream<TerminalOutput>? get outputStream => _outputController?.stream;
  Stream<TerminalSession>? get sessionStream => _sessionController?.stream;

  bool get isConnected => _webSocketChannel != null;

  // Initialize terminal service
  Future<void> initialize() async {
    _outputController ??= StreamController<TerminalOutput>.broadcast();
    _sessionController ??= StreamController<TerminalSession>.broadcast();
  }

  // Connect to local terminal (current device)
  Future<void> connectLocal() async {
    await initialize();

    // For local terminal, we can use Process.run for command execution
    // No WebSocket needed for local operations
    print('🔧 Connected to local terminal');
  }

  // Connect to remote device terminal
  Future<void> connectRemote(Device device) async {
    await initialize();

    try {
      final token = await AuthService.getToken();
      final wsUrl =
          '${ApiConfig.wsBaseUrl}/api/dock/terminal/ws/${device.id}?token=$token';

      _webSocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _webSocketChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDisconnect,
      );

      print('🔌 Connected to remote terminal: ${device.name}');
    } catch (e) {
      throw Exception('Failed to connect to remote terminal: $e');
    }
  }

  // Execute command on local device
  Future<TerminalExecutionResult> executeLocal(
    String command, {
    String? workingDirectory,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      List<String> commandParts;

      // Handle different shells and platforms
      if (Platform.isWindows) {
        commandParts = ['cmd', '/c', command];
      } else {
        commandParts = ['bash', '-c', command];
      }

      final result = await Process.run(
        commandParts[0],
        commandParts.sublist(1),
        workingDirectory: workingDirectory,
        environment: Platform.environment,
      );

      stopwatch.stop();

      return TerminalExecutionResult(
        success: result.exitCode == 0,
        output: result.stdout.toString(),
        error: result.stderr.toString(),
        exitCode: result.exitCode,
        workingDirectory: workingDirectory,
        executionTime: stopwatch.elapsed,
        environmentVariables: Platform.environment,
      );
    } catch (e) {
      stopwatch.stop();

      return TerminalExecutionResult(
        success: false,
        output: '',
        error: e.toString(),
        exitCode: -1,
        workingDirectory: workingDirectory,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  // Execute command on remote device
  Future<TerminalExecutionResult> executeRemote(
    String deviceId,
    String command, {
    String? workingDirectory,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/terminal/execute'),
        headers: headers,
        body: jsonEncode({
          'device_id': deviceId,
          'command': command,
          'working_directory': workingDirectory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TerminalExecutionResult.fromJson(data);
      } else {
        throw Exception('Command execution failed: ${response.statusCode}');
      }
    } catch (e) {
      return TerminalExecutionResult(
        success: false,
        output: '',
        error: e.toString(),
        exitCode: -1,
        workingDirectory: workingDirectory,
        executionTime: const Duration(seconds: 0),
      );
    }
  }

  // Execute command (auto-detects local vs remote)
  Future<TerminalExecutionResult> executeCommand(
    String deviceId,
    String command, {
    String? workingDirectory,
  }) async {
    // Check if this is a local device
    if (await _isLocalDevice(deviceId)) {
      return executeLocal(command, workingDirectory: workingDirectory);
    } else {
      return executeRemote(
        deviceId,
        command,
        workingDirectory: workingDirectory,
      );
    }
  }

  // Execute multiple commands in sequence
  Future<List<TerminalExecutionResult>> executeScript(
    String deviceId,
    List<String> commands, {
    String? workingDirectory,
  }) async {
    List<TerminalExecutionResult> results = [];
    String currentWorkingDir = workingDirectory ?? '~';

    for (String command in commands) {
      final result = await executeCommand(
        deviceId,
        command,
        workingDirectory: currentWorkingDir,
      );
      results.add(result);

      // Update working directory if command was successful and changed directory
      if (result.success &&
          command.startsWith('cd ') &&
          result.workingDirectory != null) {
        currentWorkingDir = result.workingDirectory!;
      }

      // Stop execution if command failed
      if (!result.success) {
        break;
      }
    }

    return results;
  }

  // Execute terminal workflow
  Future<Map<String, dynamic>> executeWorkflow(
    String deviceId,
    TerminalWorkflow workflow,
  ) async {
    final startTime = DateTime.now();
    List<Map<String, dynamic>> scriptResults = [];

    for (TerminalScript script in workflow.scripts) {
      final results = await executeScript(deviceId, script.commands);

      scriptResults.add({
        'script_id': script.id,
        'script_name': script.name,
        'results': results.map((r) => r.toJson()).toList(),
        'success': results.every((r) => r.success),
      });

      // Stop workflow if any script fails
      if (!results.every((r) => r.success)) {
        break;
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    return {
      'workflow_id': workflow.id,
      'workflow_name': workflow.name,
      'execution_time': duration.inMilliseconds,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'script_results': scriptResults,
      'overall_success': scriptResults.every((r) => r['success']),
    };
  }

  // Create new terminal session
  Future<TerminalSession> createSession(String deviceId, {String? name}) async {
    final session = TerminalSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: deviceId,
      name: name ?? 'Terminal Session',
      isActive: true,
      workingDirectory: '~',
    );

    _activeSessions[session.id] = session;
    _sessionController?.add(session);

    return session;
  }

  // Get terminal session
  TerminalSession? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  // Update session
  void updateSession(String sessionId, TerminalSession updatedSession) {
    _activeSessions[sessionId] = updatedSession;
    _sessionController?.add(updatedSession);
  }

  // Close session
  void closeSession(String sessionId) {
    _activeSessions.remove(sessionId);
  }

  // Get predefined terminal commands for platform
  List<TerminalCommand> getPredefinedCommands(String platform) {
    return _getCommandsForPlatform(platform);
  }

  // Get terminal workflows
  Future<List<TerminalWorkflow>> getWorkflows() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/terminal/workflows'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['workflows'] as List)
            .map((w) => TerminalWorkflow.fromJson(w))
            .toList();
      }
    } catch (e) {
      print('Error getting workflows: $e');
    }

    return [];
  }

  // Save terminal workflow
  Future<bool> saveWorkflow(TerminalWorkflow workflow) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/terminal/workflows'),
        headers: headers,
        body: jsonEncode(workflow.toJson()),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error saving workflow: $e');
      return false;
    }
  }

  // Disconnect from terminal
  void disconnect() {
    _webSocketChannel?.sink.close();
    _webSocketChannel = null;
    _activeSessions.clear();
  }

  // Clean up resources
  void dispose() {
    disconnect();
    _outputController?.close();
    _sessionController?.close();
    _outputController = null;
    _sessionController = null;
  }

  // Private helper methods
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'output':
          final output = TerminalOutput.fromJson(data['data']);
          _outputController?.add(output);
          break;
        case 'session_update':
          final session = TerminalSession.fromJson(data['data']);
          _activeSessions[session.id] = session;
          _sessionController?.add(session);
          break;
        case 'error':
          final errorOutput = TerminalOutput(
            text: data['message'] ?? 'Unknown error',
            isError: true,
          );
          _outputController?.add(errorOutput);
          break;
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void _handleWebSocketError(error) {
    print('WebSocket error: $error');
    final errorOutput = TerminalOutput(
      text: 'Connection error: $error',
      isError: true,
    );
    _outputController?.add(errorOutput);
  }

  void _handleWebSocketDisconnect() {
    print('WebSocket disconnected');
    _webSocketChannel = null;
    final disconnectOutput = TerminalOutput(
      text: 'Terminal disconnected',
      isWarning: true,
    );
    _outputController?.add(disconnectOutput);
  }

  Future<bool> _isLocalDevice(String deviceId) async {
    // Simple check - could be enhanced with actual device detection
    return deviceId.contains('local') ||
        deviceId.contains(Platform.localHostname);
  }

  List<TerminalCommand> _getCommandsForPlatform(String platform) {
    final baseCommands = [
      TerminalCommand(
        id: 'system_info',
        name: 'System Information',
        description: 'Get system information',
        command: _getSystemInfoCommand(platform),
        category: 'System',
        icon: Icons.info,
      ),
      TerminalCommand(
        id: 'list_files',
        name: 'List Files',
        description: 'List files in current directory',
        command: Platform.isWindows ? 'dir' : 'ls -la',
        category: 'Files',
        icon: Icons.folder,
      ),
      TerminalCommand(
        id: 'current_directory',
        name: 'Current Directory',
        description: 'Show current working directory',
        command: Platform.isWindows ? 'cd' : 'pwd',
        category: 'Navigation',
        icon: Icons.location_on,
      ),
    ];

    return baseCommands;
  }

  String _getSystemInfoCommand(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'systeminfo';
      case 'linux':
      case 'android':
        return 'uname -a';
      case 'macos':
        return 'system_profiler SPSoftwareDataType';
      default:
        return 'uname -a';
    }
  }
}
