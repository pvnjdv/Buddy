import 'dart:async';
import 'dart:convert';
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
}
