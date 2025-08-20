import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dock_models.dart';
import '../config/api_config.dart';

class DockService {
  static const String _devicesCacheKey = 'cached_devices';
  static const String _macrosCacheKey = 'cached_macros';

  static List<ConnectedDevice> _cachedDevices = [];
  static List<DockMacro> _cachedMacros = [];
  static List<MacroExecution> _activeExecutions = [];

  static Timer? _statusUpdateTimer;
  static StreamController<List<ConnectedDevice>>? _devicesController;
  static StreamController<List<MacroExecution>>? _executionsController;

  // Helper method to get authenticated headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Initialize dock service
  static Future<void> initialize() async {
    await _loadCachedData();
    _startRealTimeUpdates();
  }

  // Clean up resources
  static void dispose() {
    _statusUpdateTimer?.cancel();
    _devicesController?.close();
    _executionsController?.close();
  }

  // Real-time device monitoring
  static Stream<List<ConnectedDevice>> get devicesStream {
    _devicesController ??= StreamController<List<ConnectedDevice>>.broadcast();
    return _devicesController!.stream;
  }

  static Stream<List<MacroExecution>> get executionsStream {
    _executionsController ??=
        StreamController<List<MacroExecution>>.broadcast();
    return _executionsController!.stream;
  }

  static void _startRealTimeUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateDeviceStatuses();
      _updateExecutionStatuses();
    });
  }

  // Device Management
  static Future<List<ConnectedDevice>> getConnectedDevices({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedDevices.isNotEmpty) {
      return _cachedDevices;
    }

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = (data['devices'] as List<dynamic>)
            .map((d) => ConnectedDevice.fromJson(d))
            .toList();

        _cachedDevices = devices;
        await _cacheDevices();
        _devicesController?.add(devices);

        return devices;
      } else {
        throw Exception('Failed to fetch devices: ${response.statusCode}');
      }
    } catch (e) {
      // Return cached data on error
      return _cachedDevices;
    }
  }

  static Future<ConnectedDevice?> getDevice(String deviceId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/$deviceId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConnectedDevice.fromJson(data['device']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> registerDevice(String deviceName, String platform) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/register'),
        headers: headers,
        body: json.encode({'device_name': deviceName, 'platform': platform}),
      );

      if (response.statusCode == 201) {
        await getConnectedDevices(forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeDevice(String deviceId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/$deviceId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _cachedDevices.removeWhere((d) => d.id == deviceId);
        await _cacheDevices();
        _devicesController?.add(_cachedDevices);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Macro Management
  static Future<List<DockMacro>> getMacros() async {
    if (_cachedMacros.isNotEmpty) {
      return _cachedMacros;
    }

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dock/macros'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final macros = (data['macros'] as List<dynamic>)
            .map((m) => DockMacro.fromJson(m))
            .toList();

        _cachedMacros = macros;
        await _cacheMacros();

        return macros;
      } else {
        throw Exception('Failed to fetch macros: ${response.statusCode}');
      }
    } catch (e) {
      return _cachedMacros;
    }
  }

  static Future<DockMacro?> createMacro(DockMacro macro) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/macros'),
        headers: headers,
        body: json.encode(macro.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newMacro = DockMacro.fromJson(data['macro']);
        _cachedMacros.add(newMacro);
        await _cacheMacros();
        return newMacro;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateMacro(DockMacro macro) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/dock/macros/${macro.id}'),
        headers: headers,
        body: json.encode(macro.toJson()),
      );

      if (response.statusCode == 200) {
        final index = _cachedMacros.indexWhere((m) => m.id == macro.id);
        if (index != -1) {
          _cachedMacros[index] = macro;
          await _cacheMacros();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteMacro(String macroId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/dock/macros/$macroId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _cachedMacros.removeWhere((m) => m.id == macroId);
        await _cacheMacros();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Macro Execution
  static Future<MacroExecution?> executeMacro(
    String macroId, {
    String? deviceId,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/macros/$macroId/execute'),
        headers: headers,
        body: json.encode({if (deviceId != null) 'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final execution = MacroExecution.fromJson(data['execution']);
        _activeExecutions.add(execution);
        _executionsController?.add(_activeExecutions);
        return execution;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> cancelExecution(String executionId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/executions/$executionId/cancel'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _activeExecutions.removeWhere((e) => e.id == executionId);
        _executionsController?.add(_activeExecutions);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pauseExecution(String executionId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/executions/$executionId/pause'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> resumeExecution(String executionId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/executions/$executionId/resume'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Device Control Commands
  static Future<bool> executeCommand(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/$deviceId/command'),
        headers: headers,
        body: json.encode({'command': command, 'parameters': parameters ?? {}}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> sendFileToDevice(
    String deviceId,
    String filePath,
    String remotePath,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/$deviceId/file/send'),
        headers: headers,
        body: json.encode({'local_path': filePath, 'remote_path': remotePath}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> getFileFromDevice(
    String deviceId,
    String remotePath,
    String localPath,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/$deviceId/file/get'),
        headers: headers,
        body: json.encode({'remote_path': remotePath, 'local_path': localPath}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Automation Rules
  static Future<List<AutomationRule>> getAutomationRules() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dock/automation/rules'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['rules'] as List<dynamic>)
            .map((r) => AutomationRule.fromJson(r))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<AutomationRule?> createAutomationRule(
    AutomationRule rule,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/automation/rules'),
        headers: headers,
        body: json.encode(rule.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return AutomationRule.fromJson(data['rule']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Private helper methods
  static Future<void> _updateDeviceStatuses() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dock/devices/status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = (data['devices'] as List<dynamic>)
            .map((d) => ConnectedDevice.fromJson(d))
            .toList();

        _cachedDevices = devices;
        _devicesController?.add(devices);
      }
    } catch (e) {
      // Silent fail for real-time updates
    }
  }

  static Future<void> _updateExecutionStatuses() async {
    if (_activeExecutions.isEmpty) return;

    try {
      final headers = await _getAuthHeaders();
      final executionIds = _activeExecutions.map((e) => e.id).join(',');
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/dock/executions/status?ids=$executionIds',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final executions = (data['executions'] as List<dynamic>)
            .map((e) => MacroExecution.fromJson(e))
            .toList();

        // Update active executions and remove completed ones
        _activeExecutions = executions
            .where(
              (e) =>
                  e.status != ExecutionStatus.completed &&
                  e.status != ExecutionStatus.failed &&
                  e.status != ExecutionStatus.cancelled,
            )
            .toList();

        _executionsController?.add(_activeExecutions);
      }
    } catch (e) {
      // Silent fail for real-time updates
    }
  }

  static Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load cached devices
    final devicesJson = prefs.getString(_devicesCacheKey);
    if (devicesJson != null) {
      final devicesList = json.decode(devicesJson) as List<dynamic>;
      _cachedDevices = devicesList
          .map((d) => ConnectedDevice.fromJson(d))
          .toList();
    }

    // Load cached macros
    final macrosJson = prefs.getString(_macrosCacheKey);
    if (macrosJson != null) {
      final macrosList = json.decode(macrosJson) as List<dynamic>;
      _cachedMacros = macrosList.map((m) => DockMacro.fromJson(m)).toList();
    }
  }

  static Future<void> _cacheDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = json.encode(
      _cachedDevices.map((d) => d.toJson()).toList(),
    );
    await prefs.setString(_devicesCacheKey, devicesJson);
  }

  static Future<void> _cacheMacros() async {
    final prefs = await SharedPreferences.getInstance();
    final macrosJson = json.encode(
      _cachedMacros.map((m) => m.toJson()).toList(),
    );
    await prefs.setString(_macrosCacheKey, macrosJson);
  }

  // Quick action methods for common use cases
  static Future<bool> quickRestart(String deviceId) async {
    return await executeCommand(deviceId, 'restart');
  }

  static Future<bool> quickShutdown(String deviceId) async {
    return await executeCommand(deviceId, 'shutdown');
  }

  static Future<bool> quickSleep(String deviceId) async {
    return await executeCommand(deviceId, 'sleep');
  }

  static Future<bool> openApplication(String deviceId, String appName) async {
    return await executeCommand(
      deviceId,
      'open_app',
      parameters: {'app_name': appName},
    );
  }

  static Future<bool> closeApplication(String deviceId, String appName) async {
    return await executeCommand(
      deviceId,
      'close_app',
      parameters: {'app_name': appName},
    );
  }

  // Integration with Flow and Buddy
  static Future<bool> triggerFlowFromDevice(
    String deviceId,
    String flowDescription,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/integration/flow'),
        headers: headers,
        body: json.encode({
          'device_id': deviceId,
          'flow_description': flowDescription,
          'source': 'dock',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> askBuddyFromDevice(
    String deviceId,
    String question,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dock/integration/buddy'),
        headers: headers,
        body: json.encode({
          'device_id': deviceId,
          'question': question,
          'source': 'dock',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============ Enhanced System Monitoring ============

  /// Get comprehensive system information for dock
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final systemInfo = <String, dynamic>{};

      // Get system resources
      systemInfo['resources'] = await _getSystemResources();

      // Get running processes
      systemInfo['processes'] = await _getRunningProcesses();

      // Get network information
      systemInfo['network'] = await _getNetworkInfo();

      return systemInfo;
    } catch (e) {
      print('Error getting system info: $e');
      return {'error': e.toString()};
    }
  }

  /// Get current running processes
  static Future<List<Map<String, dynamic>>> _getRunningProcesses() async {
    try {
      final processes = <Map<String, dynamic>>[];

      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('ps', [
          '-eo',
          'pid,ppid,pcpu,pmem,comm,args',
        ]);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 6) {
                processes.add({
                  'pid': int.tryParse(parts[0]) ?? 0,
                  'ppid': int.tryParse(parts[1]) ?? 0,
                  'cpu_percent': double.tryParse(parts[2]) ?? 0.0,
                  'memory_percent': double.tryParse(parts[3]) ?? 0.0,
                  'command': parts[4],
                  'args': parts.sublist(5).join(' '),
                  'timestamp': DateTime.now().toIso8601String(),
                });
              }
            }
          }
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/fo', 'csv']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              final parts = line.split(',');
              if (parts.length >= 5) {
                processes.add({
                  'name': parts[0].replaceAll('"', ''),
                  'pid': int.tryParse(parts[1].replaceAll('"', '')) ?? 0,
                  'session_name': parts[2].replaceAll('"', ''),
                  'session_number': parts[3].replaceAll('"', ''),
                  'memory_usage': parts[4].replaceAll('"', ''),
                  'timestamp': DateTime.now().toIso8601String(),
                });
              }
            }
          }
        }
      }

      return processes;
    } catch (e) {
      print('Error getting processes: $e');
      return [];
    }
  }

  /// Kill a specific process by PID
  static Future<Map<String, dynamic>> killProcess(int pid) async {
    try {
      ProcessResult result;

      if (Platform.isWindows) {
        result = await Process.run('taskkill', ['/PID', pid.toString(), '/F']);
      } else {
        result = await Process.run('kill', ['-9', pid.toString()]);
      }

      return {
        'success': result.exitCode == 0,
        'message': result.exitCode == 0
            ? 'Process $pid terminated successfully'
            : 'Failed to terminate process $pid: ${result.stderr}',
        'pid': pid,
        'exit_code': result.exitCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error terminating process $pid: $e',
        'pid': pid,
      };
    }
  }

  /// Get system resource usage
  static Future<Map<String, dynamic>> _getSystemResources() async {
    try {
      final resources = <String, dynamic>{};

      if (Platform.isLinux || Platform.isMacOS) {
        // Get memory usage
        final memResult = await Process.run('free', ['-m']);
        if (memResult.exitCode == 0) {
          final lines = memResult.stdout.toString().split('\n');
          if (lines.length > 1) {
            final memLine = lines[1].split(RegExp(r'\s+'));
            if (memLine.length >= 3) {
              resources['memory'] = {
                'total_mb': int.tryParse(memLine[1]) ?? 0,
                'used_mb': int.tryParse(memLine[2]) ?? 0,
                'available_mb': int.tryParse(memLine[6]) ?? 0,
              };
            }
          }
        }

        // Get disk usage
        final diskResult = await Process.run('df', ['-h', '/']);
        if (diskResult.exitCode == 0) {
          final lines = diskResult.stdout.toString().split('\n');
          if (lines.length > 1) {
            final diskLine = lines[1].split(RegExp(r'\s+'));
            if (diskLine.length >= 4) {
              resources['disk'] = {
                'total': diskLine[1],
                'used': diskLine[2],
                'available': diskLine[3],
                'use_percent': diskLine[4],
              };
            }
          }
        }
      }

      return resources;
    } catch (e) {
      print('Error getting system resources: $e');
      return {};
    }
  }

  /// Get network information
  static Future<Map<String, dynamic>> _getNetworkInfo() async {
    try {
      final network = <String, dynamic>{};

      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('ifconfig', []);
        if (result.exitCode == 0) {
          network['interfaces'] = result.stdout.toString();
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('ipconfig', []);
        if (result.exitCode == 0) {
          network['interfaces'] = result.stdout.toString();
        }
      }

      return network;
    } catch (e) {
      print('Error getting network info: $e');
      return {};
    }
  }

  /// Execute a system command for dock operations
  static Future<Map<String, dynamic>> executeSystemCommand(
    String command,
    List<String> args,
  ) async {
    try {
      final result = await Process.run(command, args);
      return {
        'success': result.exitCode == 0,
        'exit_code': result.exitCode,
        'stdout': result.stdout.toString(),
        'stderr': result.stderr.toString(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
