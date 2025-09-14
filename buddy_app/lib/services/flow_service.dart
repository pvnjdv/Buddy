import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/auth_service.dart';
import '../models/flow_models.dart';
import '../models/collaboration_models.dart';
import '../config/api_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class FlowService {
  // Update the completion status of a checkpoint in a flow (backend first, fallback to local)
  static Future<ProjectFlow?> updateCheckpointStatus(
    String flowId,
    String checkpointId,
    bool isCompleted,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_completed': isCompleted}),
      );
      if (response.statusCode == 200) {
        final flowJson = jsonDecode(response.body);
        final flow = ProjectFlow.fromJson(flowJson);
        await _updateFlowLocally(flow);
        return flow;
      } else {
        throw Exception(
          'Failed to update checkpoint status: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Fallback: update locally
      final flows = await _getLocalFlows();
      final flowIndex = flows.indexWhere((f) => f.id == flowId);
      if (flowIndex != -1) {
        final flow = flows[flowIndex];
        final cpIndex = flow.checkpoints.indexWhere(
          (c) => c.id == checkpointId,
        );
        if (cpIndex != -1) {
          flow.checkpoints[cpIndex] = flow.checkpoints[cpIndex].copyWith(
            isCompleted: isCompleted,
            completedAt: isCompleted ? DateTime.now() : null,
          );
          await _updateFlowLocally(flow);
          return flow;
        }
      }
      return null;
    }
  }

  static const String _flowsKey = 'user_flows';

  // Local storage methods
  static Future<void> _saveFlowsLocally(List<ProjectFlow> flows) async {
    final prefs = await SharedPreferences.getInstance();
    final flowsJson = flows.map((flow) => flow.toJson()).toList();
    await prefs.setString(_flowsKey, jsonEncode(flowsJson));
  }

  static Future<List<ProjectFlow>> _getLocalFlows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flowsString = prefs.getString(_flowsKey);
      if (flowsString != null) {
        final List<dynamic> flowsJson = jsonDecode(flowsString);
        return flowsJson.map((json) => ProjectFlow.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error reading local flows: $e');
    }
    return [];
  }

  static Future<void> _addFlowLocally(ProjectFlow flow) async {
    final existingFlows = await _getLocalFlows();
    existingFlows.add(flow);
    await _saveFlowsLocally(existingFlows);
  }

  static Future<void> _updateFlowLocally(ProjectFlow updatedFlow) async {
    final existingFlows = await _getLocalFlows();
    final index = existingFlows.indexWhere((flow) => flow.id == updatedFlow.id);
    if (index != -1) {
      existingFlows[index] = updatedFlow;
      await _saveFlowsLocally(existingFlows);
    }
  }

  static Future<void> _deleteFlowLocally(String flowId) async {
    final existingFlows = await _getLocalFlows();
    existingFlows.removeWhere((flow) => flow.id == flowId);
    await _saveFlowsLocally(existingFlows);
  }

  // Project Flow methods
  // Update a project flow (backend first, fallback to local)
  static Future<ProjectFlow> updateProjectFlow(ProjectFlow updatedFlow) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/flows/${updatedFlow.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updatedFlow.toJson()),
      );
      if (response.statusCode == 200) {
        final flowJson = jsonDecode(response.body);
        final flow = ProjectFlow.fromJson(flowJson);
        await _updateFlowLocally(flow);
        return flow;
      } else {
        throw Exception('Failed to update flow: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local update
      await _updateFlowLocally(updatedFlow);
      return updatedFlow;
    }
  }

  // Delete a project flow (backend first, fallback to local)
  static Future<bool> deleteProjectFlow(String flowId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/flows/$flowId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _deleteFlowLocally(flowId);
        return true;
      } else {
        throw Exception('Failed to delete flow: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local delete
      await _deleteFlowLocally(flowId);
      return true;
    }
  }

  static Future<List<ProjectFlow>> getProjectFlows() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/flows/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final apiFlows = jsonList
            .map((json) => ProjectFlow.fromJson(json))
            .toList();

        // Combine API flows with local flows
        final localFlows = await _getLocalFlows();
        final allFlows = [...apiFlows, ...localFlows];

        return allFlows;
      } else {
        throw Exception('Failed to load flows: ${response.statusCode}');
      }
    } catch (e) {
      // Return local flows + mock flows for development
      final localFlows = await _getLocalFlows();
      final mockFlows = _getMockFlows();
      return [...localFlows, ...mockFlows];
    }
  }

  // New: Generate a project flow using backend AI from a description
  static Future<ProjectFlow> generateFlowFromDescription(
    String description, {
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/flows/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'project_description': description,
          'preferences': preferences ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final flowJson = data['flow'] as Map<String, dynamic>;
        final flow = ProjectFlow.fromJson(flowJson);

        // Auto-create alarms and notes for the generated flow
        await _autoCreateAlarmsAndNotes(flow);
        return flow;
      } else {
        throw Exception('Failed to auto-generate flow: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback: create a simple local flow with basic checkpoints
      final now = DateTime.now();
      final fallbackFlow = ProjectFlow(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Auto Flow',
        description: description,
        checkpoints: [
          FlowCheckpoint(
            id: '${now.millisecondsSinceEpoch}-1',
            title: 'Understand Requirements',
            description: 'Clarify goals and constraints from the description.',
            requirements: ['List objectives', 'Identify constraints'],
            deliverables: ['Requirements summary'],
            estimatedTime: '1 day',
            order: 0,
            type: CheckpointType.milestone,
          ),
          FlowCheckpoint(
            id: '${now.millisecondsSinceEpoch}-2',
            title: 'Plan Tasks',
            description: 'Break the work into actionable checkpoints.',
            requirements: ['Draft plan'],
            deliverables: ['Task list with estimates'],
            estimatedTime: '2 days',
            order: 1,
            type: CheckpointType.task,
          ),
          FlowCheckpoint(
            id: '${now.millisecondsSinceEpoch}-3',
            title: 'Review & Adapt',
            description: 'Validate plan and adjust based on feedback.',
            requirements: ['Review session'],
            deliverables: ['Updated plan'],
            estimatedTime: '1 day',
            order: 2,
            type: CheckpointType.review,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        estimatedDuration: '1 week',
        difficulty: FlowDifficulty.medium,
        tags: ['auto', 'generated'],
      );

      await _addFlowLocally(fallbackFlow);

      // Enrich fallback with alarms & notes (local/remote best-effort)
      await _autoCreateAlarmsAndNotes(fallbackFlow);
      return fallbackFlow;
    }
  }

  // Helper: create alarms and notes for each checkpoint sequentially
  static Future<void> _autoCreateAlarmsAndNotes(ProjectFlow flow) async {
    try {
      // Prefetch existing alarms and notes to avoid duplicates
      final existingAlarms = await _fetchExistingAlarms();
      final existingAlarmKeys = existingAlarms
          .map((a) => '${a.flowId ?? ''}:${a.checkpointId ?? ''}:${a.title}')
          .toSet();

      final existingNotes = await getNotes();
      final existingNoteKeys = existingNotes
          .map((n) => '${n.title}:${n.labels.join(',')}')
          .toSet();

      final checkpoints = [...flow.checkpoints]
        ..sort((a, b) => a.order.compareTo(b.order));

      var cursor = DateTime.now();
      for (final cp in checkpoints) {
        final dur = _parseEstimatedDuration(cp.estimatedTime);
        final scheduled = cursor.add(dur);

        final alarmTitle = '${flow.title}: ${cp.title}';
        final alarmKey = '${flow.id}:${cp.id}:$alarmTitle';
        if (!existingAlarmKeys.contains(alarmKey)) {
          final alarm = FlowAlarm(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: alarmTitle,
            description: 'Deadline for checkpoint "${cp.title}"',
            scheduledTime: scheduled,
            isActive: true,
            type:
                (cp.type == CheckpointType.milestone ||
                    cp.type == CheckpointType.review ||
                    cp.type == CheckpointType.testing)
                ? AlarmType.deadline
                : AlarmType.task,
            repeat: AlarmRepeat.none,
            flowId: flow.id,
            checkpointId: cp.id,
            createdAt: DateTime.now(),
          );
          await _createAlarmSmart(alarm);
        }

        final noteTitle = 'Checkpoint: ${cp.title}';
        final noteKey = '$noteTitle:${[flow.title].join(',')}';
        if (!existingNoteKeys.contains(noteKey)) {
          final noteContent = StringBuffer()
            ..writeln(cp.description)
            ..writeln('\nRequirements:')
            ..writeln(cp.requirements.map((r) => '- $r').join('\n'))
            ..writeln('\nDeliverables:')
            ..writeln(cp.deliverables.map((d) => '- $d').join('\n'))
            ..writeln('\nDeadline: ${scheduled.toLocal()}');

          final note = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: noteTitle,
            content: noteContent.toString(),
            labels: [flow.title],
            color: NoteColors.white,
            isPinned: false,
            isArchived: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            type: NoteType.text,
          );
          try {
            await createNote(note);
          } catch (_) {}
        }

        cursor = scheduled;
      }
    } catch (e) {
      // Best-effort; do not fail flow creation if enrichment fails
    }
  }

  static Future<List<FlowAlarm>> _fetchExistingAlarms() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/alarms/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => FlowAlarm.fromJson(j)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Parse strings like "2-3 days", "5 days", "1 week", "3-4 weeks", "8 hours"
  static Duration _parseEstimatedDuration(String? text) {
    if (text == null) return const Duration(days: 1);
    final s = text.toLowerCase();
    final reg = RegExp(
      r'(?:(\d+)\s*-\s*)?(\d+)\s*(day|days|week|weeks|hour|hours)',
    );
    final m = reg.firstMatch(s);
    if (m != null) {
      final start = m.group(1) != null ? int.tryParse(m.group(1)!) : null;
      final end = int.tryParse(m.group(2)!);
      final unit = m.group(3)!;
      final value = (start != null && end != null) ? end : (end ?? 1);
      switch (unit) {
        case 'day':
        case 'days':
          return Duration(days: value);
        case 'week':
        case 'weeks':
          return Duration(days: value * 7);
        case 'hour':
        case 'hours':
          return Duration(hours: value);
      }
    }
    // Fallbacks for generic terms
    if (s.contains('week')) return const Duration(days: 7);
    if (s.contains('day')) return const Duration(days: 1);
    if (s.contains('hour')) return const Duration(hours: 8);
    return const Duration(days: 1);
  }

  // Notes methods (existing functionality)
  static Future<List<Note>> getNotes() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notes/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Note.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load notes: ${response.statusCode}');
      }
    } catch (e) {
      // Return empty list for now, can be enhanced later
      return _getMockNotes();
    }
  }

  static Future<Note> createNote(Note note) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notes/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(note.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Note.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create note: ${response.statusCode}');
      }
    } catch (e) {
      // For now, return the note with a generated ID
      return note.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  static Future<Note> updateNote(Note note) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/notes/${note.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(note.toJson()),
      );

      if (response.statusCode == 200) {
        return Note.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update note: ${response.statusCode}');
      }
    } catch (e) {
      // For now, return the updated note
      return note.copyWith(updatedAt: DateTime.now());
    }
  }

  static Future<bool> deleteNote(String noteId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notes/$noteId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      // For now, return true
      return true;
    }
  }

  static Future<List<Note>> searchNotes(String query) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notes/search?q=${Uri.encodeComponent(query)}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Note.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search notes: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local filtering of mock notes
      final notes = await getNotes();
      return notes
          .where(
            (note) =>
                note.title.toLowerCase().contains(query.toLowerCase()) ||
                note.content.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  static Future<List<String>> getLabels() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notes/labels'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<String>();
      } else {
        throw Exception('Failed to load labels: ${response.statusCode}');
      }
    } catch (e) {
      return ['Personal', 'Work', 'Ideas', 'Shopping', 'Travel'];
    }
  }

  // Mock data for development
  static List<ProjectFlow> _getMockFlows() {
    return [
      ProjectFlow(
        id: '1',
        title: 'Website Development Project',
        description:
            'Create a responsive website for a local business with modern design and functionality.',
        checkpoints: [
          FlowCheckpoint(
            id: '1',
            title: 'Requirements Gathering',
            description:
                'Meet with client to understand their needs and gather all requirements.',
            requirements: [
              'Client meeting scheduled',
              'Requirements document template',
            ],
            deliverables: [
              'Requirements specification document',
              'Project scope document',
            ],
            estimatedTime: '2 days',
            order: 0,
            type: CheckpointType.milestone,
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          FlowCheckpoint(
            id: '2',
            title: 'Design Mockups',
            description:
                'Create wireframes and visual designs for the website.',
            requirements: [
              'Design tools setup',
              'Brand guidelines from client',
            ],
            deliverables: [
              'Wireframes',
              'High-fidelity mockups',
              'Design system',
            ],
            estimatedTime: '3 days',
            order: 1,
            type: CheckpointType.task,
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          FlowCheckpoint(
            id: '3',
            title: 'Frontend Development',
            description:
                'Develop the frontend using HTML, CSS, and JavaScript.',
            requirements: ['Approved designs', 'Development environment'],
            deliverables: [
              'Responsive HTML/CSS',
              'Interactive components',
              'Mobile optimization',
            ],
            estimatedTime: '5 days',
            order: 2,
            type: CheckpointType.task,
            isCompleted: false,
          ),
          FlowCheckpoint(
            id: '4',
            title: 'Backend Integration',
            description: 'Set up backend services and database integration.',
            requirements: ['Frontend completion', 'Database schema'],
            deliverables: ['API endpoints', 'Database setup', 'Admin panel'],
            estimatedTime: '4 days',
            order: 3,
            type: CheckpointType.task,
            isCompleted: false,
          ),
          FlowCheckpoint(
            id: '5',
            title: 'Testing & Launch',
            description:
                'Test the website thoroughly and deploy to production.',
            requirements: ['Completed website', 'Hosting setup'],
            deliverables: ['Test results', 'Live website', 'Documentation'],
            estimatedTime: '2 days',
            order: 4,
            type: CheckpointType.review,
            isCompleted: false,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        estimatedDuration: '2 weeks',
        difficulty: FlowDifficulty.medium,
        tags: ['web', 'frontend', 'client-work'],
        currentCheckpointIndex: 2,
      ),
      ProjectFlow(
        id: '2',
        title: 'Mobile App MVP',
        description:
            'Build a minimum viable product for a social media mobile application.',
        checkpoints: [
          FlowCheckpoint(
            id: '6',
            title: 'Market Research',
            description: 'Research competitors and define target audience.',
            requirements: ['Research tools', 'Market analysis framework'],
            deliverables: [
              'Competitor analysis',
              'User personas',
              'Market opportunity',
            ],
            estimatedTime: '3 days',
            order: 0,
            type: CheckpointType.milestone,
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          FlowCheckpoint(
            id: '7',
            title: 'App Architecture',
            description: 'Design the technical architecture and user flow.',
            requirements: ['Research findings', 'Technology stack decision'],
            deliverables: [
              'Architecture diagram',
              'User flow charts',
              'Tech stack document',
            ],
            estimatedTime: '4 days',
            order: 1,
            type: CheckpointType.task,
            isCompleted: false,
          ),
          FlowCheckpoint(
            id: '8',
            title: 'UI/UX Design',
            description: 'Create user interface designs and prototypes.',
            requirements: ['Architecture approval', 'Design tools'],
            deliverables: [
              'UI mockups',
              'Interactive prototype',
              'Design system',
            ],
            estimatedTime: '5 days',
            order: 2,
            type: CheckpointType.task,
            isCompleted: false,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        estimatedDuration: '6 weeks',
        difficulty: FlowDifficulty.hard,
        tags: ['mobile', 'mvp', 'startup'],
        currentCheckpointIndex: 1,
      ),
    ];
  }

  static List<Note> _getMockNotes() {
    return [
      Note(
        id: '1',
        title: 'Welcome to Flow',
        content:
            'This is your first note! Flow helps you capture and organize your thoughts like Google Keep.',
        labels: ['Personal'],
        color: NoteColors.yellow,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Note(
        id: '2',
        title: 'Shopping List',
        content: '',
        type: NoteType.checklist,
        checklist: [
          ChecklistItem(id: '1', text: 'Milk', isCompleted: false),
          ChecklistItem(id: '2', text: 'Bread', isCompleted: true),
          ChecklistItem(id: '3', text: 'Eggs', isCompleted: false),
          ChecklistItem(id: '4', text: 'Butter', isCompleted: false),
        ],
        labels: ['Shopping'],
        color: NoteColors.green,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Note(
        id: '3',
        title: 'Project Ideas',
        content:
            '1. Mobile app for local businesses\n2. AI-powered note-taking app\n3. Social platform for developers\n4. Recipe sharing community',
        labels: ['Work', 'Ideas'],
        color: NoteColors.blue,
        isPinned: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Note(
        id: '4',
        title: 'Meeting Notes - Q1 Planning',
        content:
            'Discussed upcoming features:\n• Enhanced chat functionality\n• AI integration improvements\n• Better task management\n\nAction items:\n- Finalize design mockups\n- Set up development milestones\n- Schedule user testing',
        labels: ['Work'],
        color: NoteColors.orange,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Note(
        id: '5',
        title: 'Travel Checklist',
        content: '',
        type: NoteType.checklist,
        checklist: [
          ChecklistItem(id: '1', text: 'Book flights', isCompleted: true),
          ChecklistItem(id: '2', text: 'Reserve hotel', isCompleted: true),
          ChecklistItem(id: '3', text: 'Pack luggage', isCompleted: false),
          ChecklistItem(id: '4', text: 'Check passport', isCompleted: true),
          ChecklistItem(
            id: '5',
            text: 'Arrange airport transfer',
            isCompleted: false,
          ),
        ],
        labels: ['Travel'],
        color: NoteColors.teal,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  // Alarms Management (centralized backend + local notifications)
  // NOTE: Removed old local-only alarms storage and duplicate helpers.
  // getAlarms/createAlarm/updateAlarm/deleteAlarm are defined below once.

  static Future<List<FlowAlarm>> getAlarms() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/alarms/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => FlowAlarm.fromJson(j)).toList();
      }
      throw Exception('Failed to fetch alarms');
    } catch (_) {
      // fallback to local storage if needed later
      return [];
    }
  }

  static Future<FlowAlarm> createAlarm(FlowAlarm alarm) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/alarms/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(alarm.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = FlowAlarm.fromJson(jsonDecode(response.body));
        await _scheduleLocalNotification(created);
        return created;
      }
      throw Exception('Failed to create alarm');
    } catch (_) {
      await _scheduleLocalNotification(alarm);
      return alarm;
    }
  }

  static Future<FlowAlarm> updateAlarm(FlowAlarm alarm) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/alarms/${alarm.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(alarm.toJson()),
      );
      if (response.statusCode == 200) {
        final updated = FlowAlarm.fromJson(jsonDecode(response.body));
        await cancelLocalNotification(updated.id.hashCode);
        await _scheduleLocalNotification(updated);
        return updated;
      }
      throw Exception('Failed to update alarm');
    } catch (_) {
      await cancelLocalNotification(alarm.id.hashCode);
      await _scheduleLocalNotification(alarm);
      return alarm;
    }
  }

  static Future<bool> deleteAlarm(String alarmId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/alarms/$alarmId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      await cancelLocalNotification(alarmId.hashCode);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      await cancelLocalNotification(alarmId.hashCode);
      return true;
    }
  }

  static Future<List<FlowAlarm>> getActiveAlarms() async {
    final alarms = await getAlarms();
    return alarms
        .where(
          (alarm) =>
              alarm.isActive && alarm.scheduledTime.isAfter(DateTime.now()),
        )
        .toList();
  }

  static Future<List<FlowAlarm>> getAlarmsForFlow(String flowId) async {
    final alarms = await getAlarms();
    return alarms.where((alarm) => alarm.flowId == flowId).toList();
  }

  // Local notifications instance (singleton)
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  static Future<void> ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _notifications.initialize(init);

    // Request notification permission on Android 13+
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    // Initialize timezone
    try {
      // Use system timezone or fallback to UTC
      tzdata.initializeTimeZones();

      // Try to detect timezone from DateTime
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final timeZoneName = _getTimeZoneFromOffset(offset);

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback to UTC if timezone detection fails
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (_) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _notificationsInitialized = true;
  }

  static Future<void> cancelLocalNotification(int id) async {
    try {
      await ensureNotificationsInitialized();
      await _notifications.cancel(id);
    } catch (_) {}
  }

  static Future<void> _scheduleLocalNotification(FlowAlarm alarm) async {
    try {
      await ensureNotificationsInitialized();
      final androidDetails = AndroidNotificationDetails(
        'buddy_alarms',
        'Buddy Alarms',
        channelDescription: 'Reminders and flow deadlines',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      final details = NotificationDetails(android: androidDetails);
      final id = alarm.id.hashCode;
      final scheduled = tz.TZDateTime.from(alarm.scheduledTime, tz.local);
      await _notifications.zonedSchedule(
        id,
        alarm.title,
        alarm.description,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _repeatToComponents(alarm.repeat),
      );
    } catch (_) {}
  }

  static DateTimeComponents? _repeatToComponents(AlarmRepeat? repeat) {
    if (repeat == null) return null;
    switch (repeat) {
      case AlarmRepeat.daily:
        return DateTimeComponents.time;
      case AlarmRepeat.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case AlarmRepeat.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case AlarmRepeat.custom:
        return null;
      case AlarmRepeat.none:
        return null;
    }
  }

  // Smart creator used by flow enrichment
  static Future<FlowAlarm> _createAlarmSmart(FlowAlarm alarm) async {
    return await createAlarm(alarm);
  }

  // Helper method to get timezone name from offset
  static String _getTimeZoneFromOffset(Duration offset) {
    final hours = offset.inHours;

    // Common timezone mappings based on offset
    switch (hours) {
      case 0:
        return 'UTC';
      case -5:
        return 'America/New_York'; // EST
      case -6:
        return 'America/Chicago'; // CST
      case -7:
        return 'America/Denver'; // MST
      case -8:
        return 'America/Los_Angeles'; // PST
      case 1:
        return 'Europe/London'; // CET
      case 2:
        return 'Europe/Berlin'; // CEST
      case 5:
      case 6:
        return 'Asia/Kolkata'; // IST
      case 8:
        return 'Asia/Shanghai'; // CST
      case 9:
        return 'Asia/Tokyo'; // JST
      default:
        // For other offsets, use UTC
        return 'UTC';
    }
  }

  // ---------- Flow WebSocket: live updates ----------
  static WebSocketChannel? _flowWs;
  static Stream<dynamic>? _flowStream;

  static void connectFlowSocket({
    required String token,
    required String flowId,
  }) {
    try {
      final base = ApiConfig.wsBaseUrl; // e.g. ws://host:port
      final uri = Uri.parse('$base/flows/ws?token=$token&flow_id=$flowId');
      _flowWs = WebSocketChannel.connect(uri);
      _flowStream = _flowWs!.stream.asBroadcastStream();
    } catch (e) {
      print('Flow WS connect error: $e');
    }
  }

  static Stream<dynamic>? get flowSocketStream => _flowStream;

  static void disconnectFlowSocket() {
    try {
      _flowWs?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _flowWs = null;
    _flowStream = null;
  }

  // -------- Dashboard --------
  static Future<Map<String, dynamic>> getFlowDashboard(String flowId) async {
    final token = await AuthService.getToken();
    final resp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/flows/$flowId/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  // -------- Scaffold --------
  static Future<void> scaffoldFlow(
    String flowId, {
    String? template,
    String? language,
  }) async {
    final token = await AuthService.getToken();
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/flows/$flowId/scaffold'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (template != null) 'template': template,
        if (language != null) 'language': language,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  // -------- Notes --------
  static Future<List<Map<String, dynamic>>> getCheckpointNotes(
    String flowId,
    String checkpointId,
  ) async {
    final token = await AuthService.getToken();
    final resp = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/notes',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  static Future<Map<String, dynamic>> createCheckpointNote(
    String flowId,
    String checkpointId, {
    required String title,
    required String content,
  }) async {
    final token = await AuthService.getToken();
    final resp = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/notes',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title, 'content': content}),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  // -------- Assignments --------
  static Future<List<Map<String, dynamic>>> getCheckpointAssignments(
    String flowId,
    String checkpointId,
  ) async {
    final token = await AuthService.getToken();
    final resp = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/assignments',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  static Future<Map<String, dynamic>> assignCheckpoint(
    String flowId,
    String checkpointId, {
    required String assigneeId,
    String? assigneeName,
  }) async {
    final token = await AuthService.getToken();
    final resp = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/assignments',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'assignee_id': assigneeId,
        if (assigneeName != null) 'assignee_name': assigneeName,
      }),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  // -------- Alarms --------
  static Future<List<Map<String, dynamic>>> getCheckpointAlarms(
    String flowId,
    String checkpointId,
  ) async {
    final token = await AuthService.getToken();
    final resp = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/alarms',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  static Future<Map<String, dynamic>> createCheckpointAlarm(
    String flowId,
    String checkpointId, {
    required String title,
    required DateTime scheduledTime,
  }) async {
    final token = await AuthService.getToken();
    final resp = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/alarms',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': '',
        'scheduled_time': scheduledTime.toIso8601String(),
        'type': 'task',
        'repeat': 'none',
      }),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${resp.statusCode}');
  }

  static Future<void> sendCodeEvent(String flowId, CodeEvent event) async {
    try {
      final token = await AuthService.getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/flows/$flowId/code-events'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(event.toJson()),
      );
    } catch (_) {}
  }
}

// Enhanced Chat Service for WhatsApp-like functionality
class EnhancedChatService {
  static WebSocketChannel? _channel;
  static Stream<dynamic>? _socketStream;

  static void connectSocket(String token) {
    try {
      final wsUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/chats/ws?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _socketStream = _channel!.stream.asBroadcastStream();
    } catch (e) {
      print('WS connect error: $e');
    }
  }

  static Stream<dynamic>? get socketStream => _socketStream;

  static void disconnectSocket() {
    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _channel = null;
    _socketStream = null;
  }

  static void sendSocketMessage({
    required String receiverId,
    required String content,
  }) {
    if (_channel == null) return;
    _channel!.sink.add(
      jsonEncode({
        'receiver_id': int.tryParse(receiverId) ?? receiverId,
        'content': content,
      }),
    );
  }

  static Future<List<ChatContact>> getContacts() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/contacts'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ChatContact.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      return _getMockContacts();
    }
  }

  static Future<bool> clearChat(String contactId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/clear'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<ChatContact>> getAllUsers() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ChatContact.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<ChatMessage>> getMessages(String contactId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/messages'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      return _getMockMessages(contactId);
    }
  }

  static Future<ChatMessage> sendMessage(
    String contactId,
    String content,
    MessageType type,
  ) async {
    try {
      final token = await AuthService.getToken();
      final body = {
        'receiver_id': int.tryParse(contactId) ?? contactId,
        'content': content,
      };
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/send'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessage.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      // Return local echo as fallback
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'current_user',
        receiverId: contactId,
        content: content,
        type: type,
        timestamp: DateTime.now(),
      );
    }
  }

  // Resolve a contact by phone number using backend
  static Future<ChatContact?> resolveContactByPhone(String phone) async {
    try {
      final encoded = Uri.encodeComponent(phone);
      final token = await AuthService.getToken();
      final resp = await http.get(
        Uri.parse('${ApiConfig.userByMobile}/$encoded'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final user = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawName = user['name'];
        final nameStr = rawName == null ? '' : rawName.toString();
        // Map to ChatContact expected shape
        return ChatContact.fromJson({
          'id': user['id'],
          'name': nameStr.isNotEmpty ? nameStr : user['mobile_number'],
          'phone_number': user['mobile_number'],
          'email': null,
          'profile_image_url': user['profile_photo'],
          'last_message': null,
          'last_message_time': null,
          'unread_count': 0,
          'is_online': false,
        });
      }
    } catch (e) {
      print('resolveContactByPhone error: $e');
    }
    return null;
  }

  // Resolve a contact by backend user ID
  static Future<ChatContact?> resolveContactById(String userId) async {
    try {
      final token = await AuthService.getToken();
      final resp = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final user = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawName = user['name'];
        final nameStr = rawName == null ? '' : rawName.toString();
        return ChatContact.fromJson({
          'id': user['id'],
          'name': nameStr.isNotEmpty ? nameStr : user['mobile_number'],
          'phone_number': user['mobile_number'],
          'email': null,
          'profile_image_url': user['profile_photo'],
          'last_message': null,
          'last_message_time': null,
          'unread_count': 0,
          'is_online': false,
        });
      }
    } catch (e) {
      print('resolveContactById error: $e');
    }
    return null;
  }

  // Mock data
  static List<ChatContact> _getMockContacts() {
    return [
      ChatContact(
        id: '1',
        name: 'Alice Johnson',
        phoneNumber: '+1234567890',
        lastMessage: 'Hey, how are you doing?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      ChatContact(
        id: '2',
        name: 'Bob Smith',
        phoneNumber: '+1987654321',
        lastMessage: 'Thanks for the help!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 0,
        isOnline: false,
      ),
      ChatContact(
        id: '3',
        name: 'Carol Davis',
        phoneNumber: '+1122334455',
        lastMessage: 'See you tomorrow',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 1,
        isOnline: true,
      ),
    ];
  }

  static List<ChatMessage> _getMockMessages(String contactId) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: '1',
        senderId: contactId,
        receiverId: 'current_user',
        content: 'Hey there!',
        timestamp: now.subtract(const Duration(minutes: 10)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: '2',
        senderId: 'current_user',
        receiverId: contactId,
        content: 'Hello! How are you?',
        timestamp: now.subtract(const Duration(minutes: 8)),
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: '3',
        senderId: contactId,
        receiverId: 'current_user',
        content: 'I\'m doing great, thanks for asking!',
        timestamp: now.subtract(const Duration(minutes: 5)),
        status: MessageStatus.read,
      ),
    ];
  }

  // Tasks Management
  static const String _tasksKey = 'user_tasks';

  static Future<List<FlowTask>> getTasks() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/tasks/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => FlowTask.fromJson(j)).toList();
      }
    } catch (_) {}

    // Fallback to local
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_tasksKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((j) => FlowTask.fromJson(j)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _saveTasksLocally(List<FlowTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  static Future<FlowTask> createTask(FlowTask task) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tasks/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(task.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return FlowTask.fromJson(jsonDecode(response.body));
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      // Local fallback
      final existing = await getTasks();
      final local = task.copyWith(
        id: task.id.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : task.id,
      );
      existing.add(local);
      await _saveTasksLocally(existing);
      return local;
    }
  }

  static Future<FlowTask> updateTask(FlowTask task) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/tasks/${task.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(task.toJson()),
      );
      if (response.statusCode == 200) {
        return FlowTask.fromJson(jsonDecode(response.body));
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      // Local fallback
      final existing = await getTasks();
      final idx = existing.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        existing[idx] = task.copyWith(updatedAt: DateTime.now());
      } else {
        existing.add(task);
      }
      await _saveTasksLocally(existing);
      return task;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (_) {}

    // Local fallback
    final existing = await getTasks();
    existing.removeWhere((t) => t.id == taskId);
    await _saveTasksLocally(existing);
    return true;
  }

  static Future<List<FlowTask>> searchTasks(String query) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/tasks/search?q=${Uri.encodeComponent(query)}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => FlowTask.fromJson(j)).toList();
      }
    } catch (_) {}

    // Local filter
    final tasks = await getTasks();
    final q = query.toLowerCase();
    return tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q),
        )
        .toList();
  }

  // Helper to create a task from quick command e.g. "task: Buy milk tomorrow 9am #shopping !high"
  static Future<FlowTask> quickCreateTask(
    String command, {
    String? flowId,
    String? checkpointId,
  }) async {
    final parsed = _parseTaskCommand(command);
    final task = FlowTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: parsed['title'] ?? 'New Task',
      description: parsed['description'] ?? '',
      dueDate: parsed['dueDate'],
      priority: parsed['priority'] ?? TaskPriority.normal,
      status: TaskStatus.todo,
      flowId: flowId,
      checkpointId: checkpointId,
      labels: parsed['labels'] ?? <String>[],
    );
    return await createTask(task);
  }

  static Map<String, dynamic> _parseTaskCommand(String cmd) {
    final map = <String, dynamic>{};
    var text = cmd.trim();
    if (text.toLowerCase().startsWith('task:')) {
      text = text.substring(5).trim();
    } else if (text.toLowerCase().startsWith('create task')) {
      text = text.substring('create task'.length).trim();
    } else if (text.toLowerCase().startsWith('add task')) {
      text = text.substring('add task'.length).trim();
    }

    // Extract labels like #work #personal
    final labelRegex = RegExp(r'(#[\w-]+)');
    final labels = labelRegex
        .allMatches(text)
        .map((m) => m.group(0)!.substring(1))
        .toList();
    text = text.replaceAll(labelRegex, '').trim();

    // Extract priority like !high !urgent
    TaskPriority priority = TaskPriority.normal;
    final prioRegex = RegExp(
      r'!(low|normal|high|urgent)',
      caseSensitive: false,
    );
    final prioMatch = prioRegex.firstMatch(text);
    if (prioMatch != null) {
      final p = prioMatch.group(1)!.toLowerCase();
      priority = TaskPriority.values.firstWhere(
        (e) => e.name == p,
        orElse: () => TaskPriority.normal,
      );
      text = text.replaceAll(prioRegex, '').trim();
    }

    // Extract simple due dates like "tomorrow 9am", "today 18:00", "in 2 days"
    DateTime? dueDate;
    final now = DateTime.now();
    final lower = text.toLowerCase();
    if (lower.contains('tomorrow')) {
      var d = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final hm = _extractTimeHM(lower);
      if (hm != null) {
        d = DateTime(d.year, d.month, d.day, hm[0], hm[1]);
      }
      dueDate = d;
      text = text.replaceAll('tomorrow', '').trim();
    } else if (lower.contains('today')) {
      final hm = _extractTimeHM(lower);
      final h = hm != null ? hm[0] : now.hour;
      final m = hm != null ? hm[1] : now.minute;
      dueDate = DateTime(now.year, now.month, now.day, h, m);
      text = text.replaceAll('today', '').trim();
    } else {
      final inRegex = RegExp(
        r'in (\d+) (minute|minutes|hour|hours|day|days|week|weeks)',
      );
      final m = inRegex.firstMatch(lower);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        final unit = m.group(2)!;
        Duration d;
        switch (unit) {
          case 'minute':
          case 'minutes':
            d = Duration(minutes: n);
            break;
          case 'hour':
          case 'hours':
            d = Duration(hours: n);
            break;
          case 'day':
          case 'days':
            d = Duration(days: n);
            break;
          default:
            d = Duration(days: 7 * n);
        }
        dueDate = now.add(d);
        text = text.replaceAll(inRegex, '').trim();
      }
    }

    // Remaining text: try split first sentence as title, rest as description
    String title = text.trim();
    String description = '';
    final dot = title.indexOf('. ');
    if (dot > 0) {
      description = title.substring(dot + 2).trim();
      title = title.substring(0, dot).trim();
    }

    map['title'] = title.isEmpty ? 'New Task' : title;
    map['description'] = description;
    map['labels'] = labels;
    map['priority'] = priority;
    map['dueDate'] = dueDate;
    return map;
  }

  static List<int>? _extractTimeHM(String s) {
    // 9am, 9:30am, 18:00
    final ampm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)');
    final m1 = ampm.firstMatch(s);
    if (m1 != null) {
      var h = int.parse(m1.group(1)!);
      final min = int.tryParse(m1.group(2) ?? '0') ?? 0;
      final ap = m1.group(3)!.toLowerCase();
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return [h, min];
    }
    final hhmm = RegExp(r'\b(\d{1,2}):(\d{2})\b');
    final m2 = hhmm.firstMatch(s);
    if (m2 != null) {
      return [int.parse(m2.group(1)!), int.parse(m2.group(2)!)];
    }
    return null;
  }

  // Quick create Note from command like "note: Buy groceries #shopping"
  static Future<Note> quickCreateNote(
    String command, {
    List<String> defaultLabels = const [],
  }) async {
    var text = command.trim();
    if (text.toLowerCase().startsWith('note:')) {
      text = text.substring(5).trim();
    } else if (text.toLowerCase().startsWith('create note')) {
      text = text.substring('create note'.length).trim();
    } else if (text.toLowerCase().startsWith('add note')) {
      text = text.substring('add note'.length).trim();
    }

    final labelRegex = RegExp(r'(#[\w-]+)');
    final labels = [
      ...defaultLabels,
      ...labelRegex.allMatches(text).map((m) => m.group(0)!.substring(1)),
    ];
    text = text.replaceAll(labelRegex, '').trim();

    // Title is up to first period or 60 chars
    String title = text.trim();
    String content = '';
    final dot = title.indexOf('. ');
    if (dot > 0) {
      content = title.substring(dot + 2).trim();
      title = title.substring(0, dot).trim();
    }
    if (title.length > 60) {
      content = title.substring(60).trim();
      title = title.substring(0, 60).trim();
    }

    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'New Note' : title,
      content: content,
      labels: labels,
      color: NoteColors.white,
      isPinned: false,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: NoteType.text,
    );
    return await FlowService.createNote(note);
  }

  // Quick create Alarm from command like "remind me to submit report tomorrow 9am" or "alarm: Meeting at 18:00 #work"
  static Future<FlowAlarm> quickCreateAlarm(
    String command, {
    String? flowId,
    String? checkpointId,
  }) async {
    var text = command.trim();
    if (text.toLowerCase().startsWith('alarm:')) {
      text = text.substring(6).trim();
    } else if (text.toLowerCase().startsWith('remind me to')) {
      text = text.substring('remind me to'.length).trim();
    } else if (text.toLowerCase().startsWith('set a reminder to')) {
      text = text.substring('set a reminder to'.length).trim();
    } else if (text.toLowerCase().startsWith('reminder:')) {
      text = text.substring('reminder:'.length).trim();
    }

    // Extract labels
    final labelRegex = RegExp(r'(#[\w-]+)');
    final labels = labelRegex
        .allMatches(text)
        .map((m) => m.group(0)!.substring(1))
        .toList();
    text = text.replaceAll(labelRegex, '').trim();

    // Try to extract due date/time
    DateTime scheduled = DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final lower = text.toLowerCase();
    bool matchedDate = false;

    if (lower.contains('tomorrow')) {
      var d = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final hm = _extractTimeHM(lower);
      if (hm != null) {
        d = DateTime(d.year, d.month, d.day, hm[0], hm[1]);
      }
      scheduled = d;
      text = text.replaceAll('tomorrow', '').trim();
      matchedDate = true;
    } else if (lower.contains('today')) {
      final hm = _extractTimeHM(lower);
      scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        hm?.first ?? now.hour,
        hm?.last ?? now.minute,
      );
      text = text.replaceAll('today', '').trim();
      matchedDate = true;
    }

    if (!matchedDate) {
      final inRegex = RegExp(
        r'in (\d+) (minute|minutes|hour|hours|day|days|week|weeks)',
      );
      final m = inRegex.firstMatch(lower);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        final unit = m.group(2)!;
        Duration d;
        switch (unit) {
          case 'minute':
          case 'minutes':
            d = Duration(minutes: n);
            break;
          case 'hour':
          case 'hours':
            d = Duration(hours: n);
            break;
          case 'day':
          case 'days':
            d = Duration(days: n);
            break;
          default:
            d = Duration(days: 7 * n);
        }
        scheduled = now.add(d);
        text = text.replaceAll(inRegex, '').trim();
        matchedDate = true;
      }
    }

    // Default title = remaining text
    final title = text.isEmpty
        ? 'Reminder'
        : text[0].toUpperCase() + text.substring(1);

    final alarm = FlowAlarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: labels.isEmpty ? '' : 'Labels: ${labels.join(', ')}',
      scheduledTime: scheduled,
      isActive: true,
      type: AlarmType.reminder,
      repeat: AlarmRepeat.none,
      flowId: flowId,
      checkpointId: checkpointId,
      createdAt: DateTime.now(),
    );

    return await FlowService.createAlarm(alarm);
  }

  // ================= COLLABORATION METHODS =================

  /// Send a flow collaboration invite via chat message
  static Future<ChatMessage> sendFlowInvite({
    required String receiverId,
    required String flowId,
    required String flowTitle,
    required CollaborationRole role,
    String? message,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/flows/$flowId/invite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiver_id': receiverId,
          'role': role.name,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatMessage.fromJson(data['chat_message']);
      } else {
        throw Exception('Failed to send flow invite: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending flow invite: $e');
      rethrow;
    }
  }

  /// Respond to a flow collaboration invite
  static Future<void> respondToFlowInvite({
    required String invitationId,
    required bool accept,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/flows/invitations/$invitationId/respond',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': accept ? 'accept' : 'reject'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to respond to invite: ${response.statusCode}');
      }
    } catch (e) {
      print('Error responding to flow invite: $e');
      rethrow;
    }
  }
}
