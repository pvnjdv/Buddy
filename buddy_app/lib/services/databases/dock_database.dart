import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Separate database service for Dock management (Devices, Macros, Automations)
/// This provides isolated storage for dock data with better performance and scalability
class DockDatabase {
  static const String _devicesKey = 'dock_devices';
  static const String _macrosKey = 'dock_macros';
  static const String _automationsKey = 'dock_automations';
  static const String _deviceHistoryKey = 'dock_device_history';
  static const String _connectionStatusKey = 'dock_connection_status';
  static const String _deviceMetadataKey = 'dock_device_metadata';

  /// Initialize the dock database
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_devicesKey)) {
      await prefs.setString(_devicesKey, '[]');
    }

    if (!prefs.containsKey(_macrosKey)) {
      await prefs.setString(_macrosKey, '[]');
    }

    if (!prefs.containsKey(_automationsKey)) {
      await prefs.setString(_automationsKey, '[]');
    }

    if (!prefs.containsKey(_deviceHistoryKey)) {
      await prefs.setString(_deviceHistoryKey, '[]');
    }
  }

  // ============== DEVICE MANAGEMENT ==============

  /// Save a device
  static Future<void> saveDevice(Map<String, dynamic> device) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey) ?? '[]';
    final List<dynamic> devices = json.decode(devicesJson);

    // Add timestamp if not present
    device['timestamp'] =
        device['timestamp'] ?? DateTime.now().toIso8601String();
    device['id'] =
        device['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    device['lastSeen'] = DateTime.now().toIso8601String();

    // Remove existing device with same ID and add updated one
    devices.removeWhere((d) => d['id'] == device['id']);
    devices.add(device);

    await prefs.setString(_devicesKey, json.encode(devices));
    await _updateDeviceHistory('device_saved', device);
  }

  /// Get all devices
  static Future<List<Map<String, dynamic>>> getAllDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey) ?? '[]';
    final List<dynamic> devices = json.decode(devicesJson);

    return devices.cast<Map<String, dynamic>>()
      ..sort((a, b) => (b['lastSeen'] ?? '').compareTo(a['lastSeen'] ?? ''));
  }

  /// Get online devices
  static Future<List<Map<String, dynamic>>> getOnlineDevices() async {
    final devices = await getAllDevices();
    return devices.where((device) => device['status'] == 'online').toList();
  }

  /// Update device status
  static Future<void> updateDeviceStatus(String deviceId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey) ?? '[]';
    final List<dynamic> devices = json.decode(devicesJson);

    final deviceIndex = devices.indexWhere(
      (device) => device['id'] == deviceId,
    );
    if (deviceIndex != -1) {
      devices[deviceIndex]['status'] = status;
      devices[deviceIndex]['lastSeen'] = DateTime.now().toIso8601String();

      await prefs.setString(_devicesKey, json.encode(devices));
      await _updateDeviceHistory('device_status_updated', {
        'id': deviceId,
        'status': status,
      });
    }
  }

  /// Delete a device
  static Future<void> deleteDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey) ?? '[]';
    final List<dynamic> devices = json.decode(devicesJson);

    devices.removeWhere((device) => device['id'] == deviceId);
    await prefs.setString(_devicesKey, json.encode(devices));

    await _updateDeviceHistory('device_deleted', {'id': deviceId});
  }

  // ============== MACRO MANAGEMENT ==============

  /// Save a macro
  static Future<void> saveMacro(Map<String, dynamic> macro) async {
    final prefs = await SharedPreferences.getInstance();
    final macrosJson = prefs.getString(_macrosKey) ?? '[]';
    final List<dynamic> macros = json.decode(macrosJson);

    // Add timestamp if not present
    macro['timestamp'] = macro['timestamp'] ?? DateTime.now().toIso8601String();
    macro['id'] =
        macro['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    macro['lastExecuted'] = macro['lastExecuted'] ?? '';

    // Remove existing macro with same ID and add updated one
    macros.removeWhere((m) => m['id'] == macro['id']);
    macros.add(macro);

    await prefs.setString(_macrosKey, json.encode(macros));
    await _updateDeviceHistory('macro_saved', macro);
  }

  /// Get all macros
  static Future<List<Map<String, dynamic>>> getAllMacros() async {
    final prefs = await SharedPreferences.getInstance();
    final macrosJson = prefs.getString(_macrosKey) ?? '[]';
    final List<dynamic> macros = json.decode(macrosJson);

    return macros.cast<Map<String, dynamic>>()
      ..sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
  }

  /// Execute macro and update execution time
  static Future<void> executeMacro(String macroId) async {
    final prefs = await SharedPreferences.getInstance();
    final macrosJson = prefs.getString(_macrosKey) ?? '[]';
    final List<dynamic> macros = json.decode(macrosJson);

    final macroIndex = macros.indexWhere((macro) => macro['id'] == macroId);
    if (macroIndex != -1) {
      macros[macroIndex]['lastExecuted'] = DateTime.now().toIso8601String();
      macros[macroIndex]['executionCount'] =
          (macros[macroIndex]['executionCount'] ?? 0) + 1;

      await prefs.setString(_macrosKey, json.encode(macros));
      await _updateDeviceHistory('macro_executed', {
        'id': macroId,
        'name': macros[macroIndex]['name'],
      });
    }
  }

  /// Delete a macro
  static Future<void> deleteMacro(String macroId) async {
    final prefs = await SharedPreferences.getInstance();
    final macrosJson = prefs.getString(_macrosKey) ?? '[]';
    final List<dynamic> macros = json.decode(macrosJson);

    macros.removeWhere((macro) => macro['id'] == macroId);
    await prefs.setString(_macrosKey, json.encode(macros));

    await _updateDeviceHistory('macro_deleted', {'id': macroId});
  }

  // ============== AUTOMATION MANAGEMENT ==============

  /// Save an automation
  static Future<void> saveAutomation(Map<String, dynamic> automation) async {
    final prefs = await SharedPreferences.getInstance();
    final automationsJson = prefs.getString(_automationsKey) ?? '[]';
    final List<dynamic> automations = json.decode(automationsJson);

    // Add timestamp if not present
    automation['timestamp'] =
        automation['timestamp'] ?? DateTime.now().toIso8601String();
    automation['id'] =
        automation['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    automation['lastTriggered'] = automation['lastTriggered'] ?? '';

    // Remove existing automation with same ID and add updated one
    automations.removeWhere((a) => a['id'] == automation['id']);
    automations.add(automation);

    await prefs.setString(_automationsKey, json.encode(automations));
    await _updateDeviceHistory('automation_saved', automation);
  }

  /// Get all automations
  static Future<List<Map<String, dynamic>>> getAllAutomations() async {
    final prefs = await SharedPreferences.getInstance();
    final automationsJson = prefs.getString(_automationsKey) ?? '[]';
    final List<dynamic> automations = json.decode(automationsJson);

    return automations.cast<Map<String, dynamic>>()
      ..sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
  }

  /// Get active automations
  static Future<List<Map<String, dynamic>>> getActiveAutomations() async {
    final automations = await getAllAutomations();
    return automations
        .where((automation) => automation['enabled'] == true)
        .toList();
  }

  /// Toggle automation status
  static Future<void> toggleAutomation(
    String automationId,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final automationsJson = prefs.getString(_automationsKey) ?? '[]';
    final List<dynamic> automations = json.decode(automationsJson);

    final automationIndex = automations.indexWhere(
      (automation) => automation['id'] == automationId,
    );
    if (automationIndex != -1) {
      automations[automationIndex]['enabled'] = enabled;
      automations[automationIndex]['lastModified'] = DateTime.now()
          .toIso8601String();

      await prefs.setString(_automationsKey, json.encode(automations));
      await _updateDeviceHistory('automation_toggled', {
        'id': automationId,
        'enabled': enabled,
      });
    }
  }

  /// Trigger automation
  static Future<void> triggerAutomation(String automationId) async {
    final prefs = await SharedPreferences.getInstance();
    final automationsJson = prefs.getString(_automationsKey) ?? '[]';
    final List<dynamic> automations = json.decode(automationsJson);

    final automationIndex = automations.indexWhere(
      (automation) => automation['id'] == automationId,
    );
    if (automationIndex != -1) {
      automations[automationIndex]['lastTriggered'] = DateTime.now()
          .toIso8601String();
      automations[automationIndex]['triggerCount'] =
          (automations[automationIndex]['triggerCount'] ?? 0) + 1;

      await prefs.setString(_automationsKey, json.encode(automations));
      await _updateDeviceHistory('automation_triggered', {
        'id': automationId,
        'name': automations[automationIndex]['name'],
      });
    }
  }

  /// Delete an automation
  static Future<void> deleteAutomation(String automationId) async {
    final prefs = await SharedPreferences.getInstance();
    final automationsJson = prefs.getString(_automationsKey) ?? '[]';
    final List<dynamic> automations = json.decode(automationsJson);

    automations.removeWhere((automation) => automation['id'] == automationId);
    await prefs.setString(_automationsKey, json.encode(automations));

    await _updateDeviceHistory('automation_deleted', {'id': automationId});
  }

  // ============== DEVICE HISTORY & CONNECTION STATUS ==============

  /// Update device history for tracking changes
  static Future<void> _updateDeviceHistory(
    String action,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_deviceHistoryKey) ?? '[]';
    final List<dynamic> history = json.decode(historyJson);

    final historyEntry = {
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    history.add(historyEntry);

    // Keep only last 500 entries for performance
    if (history.length > 500) {
      history.removeRange(0, history.length - 500);
    }

    await prefs.setString(_deviceHistoryKey, json.encode(history));
  }

  /// Get device history
  static Future<List<Map<String, dynamic>>> getDeviceHistory({
    int limit = 50,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_deviceHistoryKey) ?? '[]';
    final List<dynamic> history = json.decode(historyJson);

    final historyList = history.cast<Map<String, dynamic>>()
      ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    return historyList.take(limit).toList();
  }

  /// Get dock statistics
  static Future<Map<String, dynamic>> getDockStatistics() async {
    final devices = await getAllDevices();
    final macros = await getAllMacros();
    final automations = await getAllAutomations();
    final onlineDevices = await getOnlineDevices();
    final activeAutomations = await getActiveAutomations();

    return {
      'totalDevices': devices.length,
      'onlineDevices': onlineDevices.length,
      'offlineDevices': devices.length - onlineDevices.length,
      'totalMacros': macros.length,
      'totalAutomations': automations.length,
      'activeAutomations': activeAutomations.length,
      'devicesAddedThisWeek': devices.where((device) {
        final timestamp = DateTime.tryParse(device['timestamp'] ?? '');
        if (timestamp == null) return false;
        return DateTime.now().difference(timestamp).inDays <= 7;
      }).length,
    };
  }

  // ============== CONNECTION STATUS MANAGEMENT ==============

  /// Update connection status
  static Future<void> updateConnectionStatus(
    Map<String, dynamic> status,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    status['lastUpdated'] = DateTime.now().toIso8601String();

    await prefs.setString(_connectionStatusKey, json.encode(status));
  }

  /// Get connection status
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusJson = prefs.getString(_connectionStatusKey) ?? '{}';
    return json.decode(statusJson);
  }

  // ============== EXPORT/IMPORT ==============

  /// Export all dock data
  static Future<Map<String, dynamic>> exportAllDockData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'devices': prefs.getString(_devicesKey) ?? '[]',
      'macros': prefs.getString(_macrosKey) ?? '[]',
      'automations': prefs.getString(_automationsKey) ?? '[]',
      'deviceHistory': prefs.getString(_deviceHistoryKey) ?? '[]',
      'connectionStatus': prefs.getString(_connectionStatusKey) ?? '{}',
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Import dock data
  static Future<void> importDockData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('devices')) {
      await prefs.setString(_devicesKey, data['devices']);
    }

    if (data.containsKey('macros')) {
      await prefs.setString(_macrosKey, data['macros']);
    }

    if (data.containsKey('automations')) {
      await prefs.setString(_automationsKey, data['automations']);
    }

    if (data.containsKey('deviceHistory')) {
      await prefs.setString(_deviceHistoryKey, data['deviceHistory']);
    }

    if (data.containsKey('connectionStatus')) {
      await prefs.setString(_connectionStatusKey, data['connectionStatus']);
    }
  }

  /// Clear all dock data
  static Future<void> clearAllDockData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_devicesKey);
    await prefs.remove(_macrosKey);
    await prefs.remove(_automationsKey);
    await prefs.remove(_deviceHistoryKey);
    await prefs.remove(_connectionStatusKey);
    await prefs.remove(_deviceMetadataKey);
  }
}
