// MacroDroid-style Macro Automation Service
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/macro_models.dart';
import '../models/dock_models.dart' hide DeviceMacro;
import '../config/api_config.dart';
import '../services/auth/auth_service.dart';
import '../services/device_info_service.dart';

class MacroAutomationService {
  static final MacroAutomationService _instance =
      MacroAutomationService._internal();
  factory MacroAutomationService() => _instance;
  MacroAutomationService._internal();

  // Service state
  final List<DeviceMacro> _macros = [];
  final List<MacroExecution> _executions = [];
  final Map<String, MacroVariable> _variables = {};
  final List<MacroTemplate> _templates = [];

  // Event streams
  final StreamController<DeviceMacro> _macroExecutedController =
      StreamController.broadcast();
  final StreamController<MacroExecution> _executionStatusController =
      StreamController.broadcast();
  final StreamController<List<DeviceMacro>> _macrosUpdatedController =
      StreamController.broadcast();

  // Public streams
  Stream<DeviceMacro> get macroExecuted => _macroExecutedController.stream;
  Stream<MacroExecution> get executionStatus =>
      _executionStatusController.stream;
  Stream<List<DeviceMacro>> get macrosUpdated =>
      _macrosUpdatedController.stream;

  // Background execution
  Timer? _automationTimer;
  bool _isRunning = false;

  // HTTP Helper Methods
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Macro Management
  Future<List<DeviceMacro>> getAllMacros({String? deviceId}) async {
    try {
      final headers = await _getAuthHeaders();
      final url = deviceId != null
          ? '${ApiConfig.baseUrl}/api/dock/macros?device_id=$deviceId'
          : '${ApiConfig.baseUrl}/api/dock/macros';

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final macros = (data['macros'] as List)
            .map((json) => DeviceMacro.fromJson(json))
            .toList();

        _macros.clear();
        _macros.addAll(macros);
        _macrosUpdatedController.add(_macros);

        return macros;
      } else {
        throw Exception('Failed to fetch macros: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching macros: $e');
      return [];
    }
  }

  Future<DeviceMacro?> createMacro(DeviceMacro macro) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/macros'),
        headers: headers,
        body: jsonEncode(macro.toJson()),
      );

      if (response.statusCode == 201) {
        final createdMacro = DeviceMacro.fromJson(jsonDecode(response.body));
        _macros.add(createdMacro);
        _macrosUpdatedController.add(_macros);
        return createdMacro;
      } else {
        throw Exception('Failed to create macro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating macro: $e');
      return null;
    }
  }

  Future<DeviceMacro?> updateMacro(DeviceMacro macro) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/macros/${macro.id}'),
        headers: headers,
        body: jsonEncode(macro.toJson()),
      );

      if (response.statusCode == 200) {
        final updatedMacro = DeviceMacro.fromJson(jsonDecode(response.body));
        final index = _macros.indexWhere((m) => m.id == macro.id);
        if (index != -1) {
          _macros[index] = updatedMacro;
          _macrosUpdatedController.add(_macros);
        }
        return updatedMacro;
      } else {
        throw Exception('Failed to update macro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating macro: $e');
      return null;
    }
  }

  Future<bool> deleteMacro(String macroId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/dock/macros/$macroId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _macros.removeWhere((m) => m.id == macroId);
        _macrosUpdatedController.add(_macros);
        return true;
      } else {
        throw Exception('Failed to delete macro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting macro: $e');
      return false;
    }
  }

  Future<bool> toggleMacroEnabled(String macroId, bool enabled) async {
    final macro = _macros.firstWhere((m) => m.id == macroId);
    final updatedMacro = DeviceMacro(
      id: macro.id,
      name: macro.name,
      description: macro.description,
      deviceId: macro.deviceId,
      triggers: macro.triggers,
      conditions: macro.conditions,
      actions: macro.actions,
      enabled: enabled,
      category: macro.category,
      tags: macro.tags,
      executionCount: macro.executionCount,
      lastExecuted: macro.lastExecuted,
      createdAt: macro.createdAt,
      updatedAt: DateTime.now(),
      runInBackground: macro.runInBackground,
      maxExecutionsPerDay: macro.maxExecutionsPerDay,
    );

    final result = await updateMacro(updatedMacro);
    return result != null;
  }

  // Macro Execution
  Future<MacroExecution?> executeMacro(
    String macroId, {
    TriggerType? triggerType,
  }) async {
    try {
      final macro = _macros.firstWhere((m) => m.id == macroId);

      if (!macro.enabled) {
        debugPrint('Macro ${macro.name} is disabled');
        return null;
      }

      // Check conditions first
      final conditionsMet = await _checkConditions(macro.conditions);
      if (!conditionsMet) {
        debugPrint('Conditions not met for macro ${macro.name}');
        return null;
      }

      // Create execution record
      final execution = MacroExecution(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        macroId: macroId,
        deviceId: macro.deviceId,
        triggerType: triggerType ?? TriggerType.manual,
        status: 'running',
        startedAt: DateTime.now(),
        totalActions: macro.actions.length,
      );

      _executions.add(execution);
      _executionStatusController.add(execution);

      // Execute actions
      final success = await _executeActions(macro.actions, execution);

      // Update execution status
      final completedExecution = MacroExecution(
        id: execution.id,
        macroId: execution.macroId,
        deviceId: execution.deviceId,
        triggerType: execution.triggerType,
        status: success ? 'completed' : 'failed',
        startedAt: execution.startedAt,
        completedAt: DateTime.now(),
        totalActions: execution.totalActions,
        actionsCompleted: success
            ? execution.totalActions
            : execution.actionsCompleted,
        executionLog: execution.executionLog,
        errorMessage: success ? null : 'One or more actions failed',
      );

      // Update execution in list
      final execIndex = _executions.indexWhere((e) => e.id == execution.id);
      if (execIndex != -1) {
        _executions[execIndex] = completedExecution;
      }

      _executionStatusController.add(completedExecution);
      _macroExecutedController.add(macro);

      // Update macro execution count
      await _updateMacroExecutionCount(macroId);

      return completedExecution;
    } catch (e) {
      debugPrint('Error executing macro: $e');
      return null;
    }
  }

  // Trigger checking and automation
  void startAutomation() {
    if (_isRunning) return;

    _isRunning = true;
    _automationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkTriggers();
    });

    debugPrint('Macro automation started');
  }

  void stopAutomation() {
    _isRunning = false;
    _automationTimer?.cancel();
    _automationTimer = null;
    debugPrint('Macro automation stopped');
  }

  Future<void> _checkTriggers() async {
    for (final macro in _macros.where((m) => m.enabled)) {
      for (final trigger in macro.triggers.where((t) => t.enabled)) {
        final shouldExecute = await _evaluateTrigger(trigger);
        if (shouldExecute) {
          await executeMacro(macro.id, triggerType: trigger.type);
        }
      }
    }
  }

  Future<bool> _evaluateTrigger(MacroTrigger trigger) async {
    switch (trigger.type) {
      case TriggerType.time:
        return _evaluateTimeTrigger(trigger);
      case TriggerType.deviceState:
        return await _evaluateDeviceStateTrigger(trigger);
      case TriggerType.network:
        return await _evaluateNetworkTrigger(trigger);
      case TriggerType.battery:
        return await _evaluateBatteryTrigger(trigger);
      case TriggerType.location:
        return await _evaluateLocationTrigger(trigger);
      case TriggerType.deviceConnect:
        return await _evaluateDeviceConnectTrigger(trigger);
      default:
        return false;
    }
  }

  bool _evaluateTimeTrigger(MacroTrigger trigger) {
    final config = trigger.configuration;
    final now = DateTime.now();

    // Daily time trigger
    if (config['type'] == 'daily') {
      final timeStr = config['time'] as String?;
      if (timeStr != null) {
        final timeParts = timeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        return now.hour == hour && now.minute == minute;
      }
    }

    // Weekly trigger
    if (config['type'] == 'weekly') {
      final weekdays = config['weekdays'] as List<dynamic>?;
      final timeStr = config['time'] as String?;

      if (weekdays != null && timeStr != null) {
        final currentWeekday = now.weekday;
        if (weekdays.contains(currentWeekday)) {
          final timeParts = timeStr.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);

          return now.hour == hour && now.minute == minute;
        }
      }
    }

    return false;
  }

  Future<bool> _evaluateDeviceStateTrigger(MacroTrigger trigger) async {
    final config = trigger.configuration;
    final deviceId = config['device_id'] as String?;
    final expectedState = config['state'] as String?;

    if (deviceId != null && expectedState != null) {
      // Check device state via API or local cache
      // This would integrate with your existing device management
      return false; // Placeholder
    }

    return false;
  }

  Future<bool> _evaluateNetworkTrigger(MacroTrigger trigger) async {
    final config = trigger.configuration;
    final networkType = config['network_type'] as String?;

    if (networkType == 'wifi_connected') {
      // Check WiFi connection status
      return false; // Placeholder - integrate with connectivity service
    }

    return false;
  }

  Future<bool> _evaluateBatteryTrigger(MacroTrigger trigger) async {
    final config = trigger.configuration;
    final threshold = config['battery_threshold'] as int?;
    final condition = config['condition'] as String?; // 'below', 'above'

    if (threshold != null && condition != null) {
      // Get battery level from device info service
      return false; // Placeholder
    }

    return false;
  }

  Future<bool> _evaluateLocationTrigger(MacroTrigger trigger) async {
    final config = trigger.configuration;
    final latitude = config['latitude'] as double?;
    final longitude = config['longitude'] as double?;
    final radius = config['radius'] as double?;

    if (latitude != null && longitude != null && radius != null) {
      // Check if current location is within radius
      return false; // Placeholder - integrate with location service
    }

    return false;
  }

  Future<bool> _evaluateDeviceConnectTrigger(MacroTrigger trigger) async {
    final config = trigger.configuration;
    final deviceName = config['device_name'] as String?;
    final connectionType =
        config['connection_type'] as String?; // 'bluetooth', 'wifi', 'usb'

    if (deviceName != null && connectionType != null) {
      // Check if specific device is connected
      return false; // Placeholder
    }

    return false;
  }

  Future<bool> _checkConditions(List<MacroCondition> conditions) async {
    if (conditions.isEmpty) return true;

    for (final condition in conditions.where((c) => c.enabled)) {
      final result = await _evaluateCondition(condition);
      final finalResult = condition.inverted ? !result : result;

      if (!finalResult) {
        return false; // All conditions must be true
      }
    }

    return true;
  }

  Future<bool> _evaluateCondition(MacroCondition condition) async {
    switch (condition.type) {
      case ConditionType.timeRange:
        return _evaluateTimeRangeCondition(condition);
      case ConditionType.batteryLevel:
        return await _evaluateBatteryCondition(condition);
      case ConditionType.networkStatus:
        return await _evaluateNetworkCondition(condition);
      case ConditionType.deviceState:
        return await _evaluateDeviceStateCondition(condition);
      default:
        return true;
    }
  }

  bool _evaluateTimeRangeCondition(MacroCondition condition) {
    final config = condition.configuration;
    final startTime = config['start_time'] as String?;
    final endTime = config['end_time'] as String?;

    if (startTime != null && endTime != null) {
      final now = DateTime.now();
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);

      final currentMinutes = now.hour * 60 + now.minute;

      if (start <= end) {
        return currentMinutes >= start && currentMinutes <= end;
      } else {
        // Crosses midnight
        return currentMinutes >= start || currentMinutes <= end;
      }
    }

    return true;
  }

  int _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<bool> _evaluateBatteryCondition(MacroCondition condition) async {
    final config = condition.configuration;
    final threshold = config['threshold'] as int?;
    final operator =
        config['operator']
            as String?; // 'greater_than', 'less_than', 'equal_to'

    if (threshold != null && operator != null) {
      // Get current battery level
      final batteryLevel = 50; // Placeholder - integrate with battery service

      switch (operator) {
        case 'greater_than':
          return batteryLevel > threshold;
        case 'less_than':
          return batteryLevel < threshold;
        case 'equal_to':
          return batteryLevel == threshold;
        default:
          return true;
      }
    }

    return true;
  }

  Future<bool> _evaluateNetworkCondition(MacroCondition condition) async {
    final config = condition.configuration;
    final networkType = config['network_type'] as String?;

    if (networkType != null) {
      // Check current network type
      return false; // Placeholder
    }

    return true;
  }

  Future<bool> _evaluateDeviceStateCondition(MacroCondition condition) async {
    final config = condition.configuration;
    final deviceId = config['device_id'] as String?;
    final expectedState = config['state'] as String?;

    if (deviceId != null && expectedState != null) {
      // Check device state
      return false; // Placeholder
    }

    return true;
  }

  Future<bool> _executeActions(
    List<MacroAction> actions,
    MacroExecution execution,
  ) async {
    final sortedActions = actions.where((a) => a.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final action in sortedActions) {
      try {
        final success = await _executeAction(action);

        if (success) {
          execution = MacroExecution(
            id: execution.id,
            macroId: execution.macroId,
            deviceId: execution.deviceId,
            triggerType: execution.triggerType,
            status: execution.status,
            startedAt: execution.startedAt,
            completedAt: execution.completedAt,
            totalActions: execution.totalActions,
            actionsCompleted: execution.actionsCompleted + 1,
            executionLog: [
              ...execution.executionLog,
              {
                'action_id': action.id,
                'action_name': action.name,
                'status': 'completed',
                'timestamp': DateTime.now().toIso8601String(),
              },
            ],
            errorMessage: execution.errorMessage,
          );
        } else {
          execution = MacroExecution(
            id: execution.id,
            macroId: execution.macroId,
            deviceId: execution.deviceId,
            triggerType: execution.triggerType,
            status: 'failed',
            startedAt: execution.startedAt,
            completedAt: execution.completedAt,
            totalActions: execution.totalActions,
            actionsCompleted: execution.actionsCompleted,
            executionLog: [
              ...execution.executionLog,
              {
                'action_id': action.id,
                'action_name': action.name,
                'status': 'failed',
                'timestamp': DateTime.now().toIso8601String(),
              },
            ],
            errorMessage: 'Action ${action.name} failed',
          );

          if (!action.continueOnError) {
            return false;
          }
        }

        _executionStatusController.add(execution);

        // Handle delays
        final delayMs = action.delayMs;
        if (delayMs != null && delayMs > 0) {
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      } catch (e) {
        debugPrint('Error executing action ${action.name}: $e');
        if (!action.continueOnError) {
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> _executeAction(MacroAction action) async {
    switch (action.type) {
      case ActionType.systemAction:
        return await _executeSystemAction(action);
      case ActionType.notification:
        return await _executeNotificationAction(action);
      case ActionType.deviceControl:
        return await _executeDeviceControlAction(action);
      case ActionType.wait:
        return await _executeWaitAction(action);
      case ActionType.appControl:
        return await _executeAppControlAction(action);
      case ActionType.fileOperation:
        return await _executeFileOperationAction(action);
      case ActionType.variable:
        return await _executeVariableAction(action);
      default:
        debugPrint('Unknown action type: ${action.type}');
        return false;
    }
  }

  Future<bool> _executeSystemAction(MacroAction action) async {
    final config = action.configuration;
    final systemAction = config['action'] as String?;

    if (systemAction != null) {
      // Execute system command via dock service
      debugPrint('Executing system action: $systemAction');
      return true; // Placeholder
    }

    return false;
  }

  Future<bool> _executeNotificationAction(MacroAction action) async {
    final config = action.configuration;
    final message = config['message'] as String?;
    final title = config['title'] as String?;

    if (message != null) {
      // Show notification
      debugPrint('Showing notification: $title - $message');
      return true; // Placeholder
    }

    return false;
  }

  Future<bool> _executeDeviceControlAction(MacroAction action) async {
    final config = action.configuration;
    final deviceId = config['device_id'] as String?;
    final command = config['command'] as String?;

    if (deviceId != null && command != null) {
      // Send command to device via dock service
      debugPrint('Sending command to device $deviceId: $command');
      return true; // Placeholder
    }

    return false;
  }

  Future<bool> _executeWaitAction(MacroAction action) async {
    final config = action.configuration;
    final durationMs = config['duration_ms'] as int?;

    if (durationMs != null) {
      await Future.delayed(Duration(milliseconds: durationMs));
      return true;
    }

    return false;
  }

  Future<bool> _executeAppControlAction(MacroAction action) async {
    final config = action.configuration;
    final appAction = config['action'] as String?; // 'launch', 'close', 'focus'
    final appName = config['app_name'] as String?;

    if (appAction != null && appName != null) {
      debugPrint('App control: $appAction for $appName');
      return true; // Placeholder
    }

    return false;
  }

  Future<bool> _executeFileOperationAction(MacroAction action) async {
    final config = action.configuration;
    final operation =
        config['operation'] as String?; // 'copy', 'move', 'delete', 'create'
    final filePath = config['file_path'] as String?;

    if (operation != null && filePath != null) {
      debugPrint('File operation: $operation on $filePath');
      return true; // Placeholder
    }

    return false;
  }

  Future<bool> _executeVariableAction(MacroAction action) async {
    final config = action.configuration;
    final variableName = config['variable_name'] as String?;
    final operation =
        config['operation'] as String?; // 'set', 'increment', 'append'
    final value = config['value'];

    if (variableName != null && operation != null) {
      switch (operation) {
        case 'set':
          await setVariable(variableName, value);
          break;
        case 'increment':
          final current = getVariable(variableName) ?? 0;
          await setVariable(variableName, (current as num) + (value as num));
          break;
        case 'append':
          final current = getVariable(variableName) ?? '';
          await setVariable(variableName, '$current$value');
          break;
      }
      return true;
    }

    return false;
  }

  Future<void> _updateMacroExecutionCount(String macroId) async {
    final macro = _macros.firstWhere((m) => m.id == macroId);
    final updatedMacro = DeviceMacro(
      id: macro.id,
      name: macro.name,
      description: macro.description,
      deviceId: macro.deviceId,
      triggers: macro.triggers,
      conditions: macro.conditions,
      actions: macro.actions,
      enabled: macro.enabled,
      category: macro.category,
      tags: macro.tags,
      executionCount: macro.executionCount + 1,
      lastExecuted: DateTime.now(),
      createdAt: macro.createdAt,
      updatedAt: DateTime.now(),
      runInBackground: macro.runInBackground,
      maxExecutionsPerDay: macro.maxExecutionsPerDay,
    );

    await updateMacro(updatedMacro);
  }

  // Variable Management
  Future<void> setVariable(String name, dynamic value) async {
    final variable = MacroVariable(
      name: name,
      type: _getValueType(value),
      value: value,
      persistent: true,
      createdAt: _variables[name]?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _variables[name] = variable;

    // Persist to storage if needed
    debugPrint('Set variable $name = $value');
  }

  dynamic getVariable(String name) {
    return _variables[name]?.value;
  }

  String _getValueType(dynamic value) {
    if (value is String) return 'string';
    if (value is num) return 'number';
    if (value is bool) return 'boolean';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return 'unknown';
  }

  // Template Management
  Future<List<MacroTemplate>> getTemplates({String? category}) async {
    try {
      final headers = await _getAuthHeaders();
      final url = category != null
          ? '${ApiConfig.baseUrl}/api/dock/macro-templates?category=$category'
          : '${ApiConfig.baseUrl}/api/dock/macro-templates';

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final templates = (data['templates'] as List)
            .map((json) => MacroTemplate.fromJson(json))
            .toList();

        _templates.clear();
        _templates.addAll(templates);

        return templates;
      } else {
        throw Exception('Failed to fetch templates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching templates: $e');
      return [];
    }
  }

  Future<DeviceMacro?> createMacroFromTemplate(
    String templateId,
    String deviceId, {
    Map<String, dynamic>? customConfig,
  }) async {
    try {
      final template = _templates.firstWhere((t) => t.id == templateId);
      final templateData = template.template;

      // Apply custom configuration if provided
      if (customConfig != null) {
        templateData.addAll(customConfig);
      }

      // Create macro from template
      final macro = DeviceMacro(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: templateData['name'] ?? template.name,
        description: templateData['description'] ?? template.description,
        deviceId: deviceId,
        triggers: (templateData['triggers'] as List)
            .map((json) => MacroTrigger.fromJson(json))
            .toList(),
        conditions: (templateData['conditions'] as List)
            .map((json) => MacroCondition.fromJson(json))
            .toList(),
        actions: (templateData['actions'] as List)
            .map((json) => MacroAction.fromJson(json))
            .toList(),
        enabled: templateData['enabled'] ?? true,
        category: template.category,
        tags: Map<String, String>.from(templateData['tags'] ?? {}),
        executionCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        runInBackground: templateData['run_in_background'] ?? false,
        maxExecutionsPerDay: templateData['max_executions_per_day'],
      );

      return await createMacro(macro);
    } catch (e) {
      debugPrint('Error creating macro from template: $e');
      return null;
    }
  }

  // Cleanup
  void dispose() {
    stopAutomation();
    _macroExecutedController.close();
    _executionStatusController.close();
    _macrosUpdatedController.close();
  }

  // Getters for current state
  List<DeviceMacro> get macros => List.unmodifiable(_macros);
  List<MacroExecution> get executions => List.unmodifiable(_executions);
  Map<String, MacroVariable> get variables => Map.unmodifiable(_variables);
  List<MacroTemplate> get templates => List.unmodifiable(_templates);
  bool get isRunning => _isRunning;
}
