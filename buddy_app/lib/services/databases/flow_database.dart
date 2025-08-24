import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Separate database service for Flow management (Notes & Alarms)
/// This provides isolated storage for flow data with better performance and scalability
class FlowDatabase {
  static const String _notesKey = 'flow_notes';
  static const String _alarmsKey = 'flow_alarms';
  static const String _flowHistoryKey = 'flow_history';
  static const String _activeFlowsKey = 'active_flows';
  static const String _flowMetadataKey = 'flow_metadata';

  /// Initialize the flow database
  static Future<void> initialize() async {
    // Initialize default values if needed
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_notesKey)) {
      await prefs.setString(_notesKey, '[]');
    }

    if (!prefs.containsKey(_alarmsKey)) {
      await prefs.setString(_alarmsKey, '[]');
    }

    if (!prefs.containsKey(_flowHistoryKey)) {
      await prefs.setString(_flowHistoryKey, '[]');
    }
  }

  // ============== NOTES MANAGEMENT ==============

  /// Save a note
  static Future<void> saveNote(Map<String, dynamic> note) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_notesKey) ?? '[]';
    final List<dynamic> notes = json.decode(notesJson);

    // Add timestamp if not present
    note['timestamp'] = note['timestamp'] ?? DateTime.now().toIso8601String();
    note['id'] = note['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Remove existing note with same ID and add updated one
    notes.removeWhere((n) => n['id'] == note['id']);
    notes.add(note);

    await prefs.setString(_notesKey, json.encode(notes));
    await _updateFlowHistory('note_saved', note);
  }

  /// Get all notes
  static Future<List<Map<String, dynamic>>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_notesKey) ?? '[]';
    final List<dynamic> notes = json.decode(notesJson);

    return notes.cast<Map<String, dynamic>>()
      ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
  }

  /// Delete a note
  static Future<void> deleteNote(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_notesKey) ?? '[]';
    final List<dynamic> notes = json.decode(notesJson);

    notes.removeWhere((note) => note['id'] == noteId);
    await prefs.setString(_notesKey, json.encode(notes));

    await _updateFlowHistory('note_deleted', {'id': noteId});
  }

  /// Search notes
  static Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final notes = await getAllNotes();
    final lowercaseQuery = query.toLowerCase();

    return notes.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final content = (note['content'] ?? '').toString().toLowerCase();
      final labels = (note['labels'] ?? []).join(' ').toLowerCase();

      return title.contains(lowercaseQuery) ||
          content.contains(lowercaseQuery) ||
          labels.contains(lowercaseQuery);
    }).toList();
  }

  // ============== ALARMS MANAGEMENT ==============

  /// Save an alarm
  static Future<void> saveAlarm(Map<String, dynamic> alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
    final List<dynamic> alarms = json.decode(alarmsJson);

    // Add timestamp if not present
    alarm['timestamp'] = alarm['timestamp'] ?? DateTime.now().toIso8601String();
    alarm['id'] =
        alarm['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Remove existing alarm with same ID and add updated one
    alarms.removeWhere((a) => a['id'] == alarm['id']);
    alarms.add(alarm);

    await prefs.setString(_alarmsKey, json.encode(alarms));
    await _updateFlowHistory('alarm_saved', alarm);
  }

  /// Get all alarms
  static Future<List<Map<String, dynamic>>> getAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
    final List<dynamic> alarms = json.decode(alarmsJson);

    return alarms.cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['datetime'] ?? '').compareTo(b['datetime'] ?? ''));
  }

  /// Delete an alarm
  static Future<void> deleteAlarm(String alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
    final List<dynamic> alarms = json.decode(alarmsJson);

    alarms.removeWhere((alarm) => alarm['id'] == alarmId);
    await prefs.setString(_alarmsKey, json.encode(alarms));

    await _updateFlowHistory('alarm_deleted', {'id': alarmId});
  }

  /// Get active alarms (not completed/dismissed)
  static Future<List<Map<String, dynamic>>> getActiveAlarms() async {
    final alarms = await getAllAlarms();
    return alarms
        .where(
          (alarm) =>
              alarm['status'] != 'completed' && alarm['status'] != 'dismissed',
        )
        .toList();
  }

  /// Update alarm status
  static Future<void> updateAlarmStatus(String alarmId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey) ?? '[]';
    final List<dynamic> alarms = json.decode(alarmsJson);

    final alarmIndex = alarms.indexWhere((alarm) => alarm['id'] == alarmId);
    if (alarmIndex != -1) {
      alarms[alarmIndex]['status'] = status;
      alarms[alarmIndex]['lastUpdated'] = DateTime.now().toIso8601String();

      await prefs.setString(_alarmsKey, json.encode(alarms));
      await _updateFlowHistory('alarm_status_updated', {
        'id': alarmId,
        'status': status,
      });
    }
  }

  // ============== FLOW HISTORY & METADATA ==============

  /// Update flow history for tracking changes
  static Future<void> _updateFlowHistory(
    String action,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_flowHistoryKey) ?? '[]';
    final List<dynamic> history = json.decode(historyJson);

    final historyEntry = {
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    history.add(historyEntry);

    // Keep only last 1000 entries for performance
    if (history.length > 1000) {
      history.removeRange(0, history.length - 1000);
    }

    await prefs.setString(_flowHistoryKey, json.encode(history));
  }

  /// Get flow history
  static Future<List<Map<String, dynamic>>> getFlowHistory({
    int limit = 100,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_flowHistoryKey) ?? '[]';
    final List<dynamic> history = json.decode(historyJson);

    final historyList = history.cast<Map<String, dynamic>>()
      ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    return historyList.take(limit).toList();
  }

  /// Get flow statistics
  static Future<Map<String, dynamic>> getFlowStatistics() async {
    final notes = await getAllNotes();
    final alarms = await getAllAlarms();
    final activeAlarms = await getActiveAlarms();

    return {
      'totalNotes': notes.length,
      'totalAlarms': alarms.length,
      'activeAlarms': activeAlarms.length,
      'completedAlarms': alarms.length - activeAlarms.length,
      'notesThisWeek': notes.where((note) {
        final timestamp = DateTime.tryParse(note['timestamp'] ?? '');
        if (timestamp == null) return false;
        return DateTime.now().difference(timestamp).inDays <= 7;
      }).length,
      'alarmsThisWeek': alarms.where((alarm) {
        final timestamp = DateTime.tryParse(alarm['timestamp'] ?? '');
        if (timestamp == null) return false;
        return DateTime.now().difference(timestamp).inDays <= 7;
      }).length,
    };
  }

  // ============== ACTIVE FLOWS MANAGEMENT ==============

  /// Track active flows (flows in progress)
  static Future<void> addActiveFlow(Map<String, dynamic> flow) async {
    final prefs = await SharedPreferences.getInstance();
    final activeFlowsJson = prefs.getString(_activeFlowsKey) ?? '[]';
    final List<dynamic> activeFlows = json.decode(activeFlowsJson);

    flow['startTime'] = DateTime.now().toIso8601String();
    flow['status'] = 'active';

    activeFlows.add(flow);
    await prefs.setString(_activeFlowsKey, json.encode(activeFlows));
  }

  /// Complete an active flow
  static Future<void> completeActiveFlow(String flowId) async {
    final prefs = await SharedPreferences.getInstance();
    final activeFlowsJson = prefs.getString(_activeFlowsKey) ?? '[]';
    final List<dynamic> activeFlows = json.decode(activeFlowsJson);

    final flowIndex = activeFlows.indexWhere((flow) => flow['id'] == flowId);
    if (flowIndex != -1) {
      activeFlows[flowIndex]['status'] = 'completed';
      activeFlows[flowIndex]['completedTime'] = DateTime.now()
          .toIso8601String();

      await prefs.setString(_activeFlowsKey, json.encode(activeFlows));
      await _updateFlowHistory('flow_completed', {'id': flowId});
    }
  }

  /// Get active flows
  static Future<List<Map<String, dynamic>>> getActiveFlows() async {
    final prefs = await SharedPreferences.getInstance();
    final activeFlowsJson = prefs.getString(_activeFlowsKey) ?? '[]';
    final List<dynamic> activeFlows = json.decode(activeFlowsJson);

    return activeFlows
        .cast<Map<String, dynamic>>()
        .where((flow) => flow['status'] == 'active')
        .toList();
  }

  // ============== EXPORT/IMPORT ==============

  /// Export all flow data
  static Future<Map<String, dynamic>> exportAllFlowData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'notes': prefs.getString(_notesKey) ?? '[]',
      'alarms': prefs.getString(_alarmsKey) ?? '[]',
      'flowHistory': prefs.getString(_flowHistoryKey) ?? '[]',
      'activeFlows': prefs.getString(_activeFlowsKey) ?? '[]',
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Import flow data
  static Future<void> importFlowData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('notes')) {
      await prefs.setString(_notesKey, data['notes']);
    }

    if (data.containsKey('alarms')) {
      await prefs.setString(_alarmsKey, data['alarms']);
    }

    if (data.containsKey('flowHistory')) {
      await prefs.setString(_flowHistoryKey, data['flowHistory']);
    }

    if (data.containsKey('activeFlows')) {
      await prefs.setString(_activeFlowsKey, data['activeFlows']);
    }
  }

  /// Clear all flow data
  static Future<void> clearAllFlowData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_notesKey);
    await prefs.remove(_alarmsKey);
    await prefs.remove(_flowHistoryKey);
    await prefs.remove(_activeFlowsKey);
    await prefs.remove(_flowMetadataKey);
  }
}
