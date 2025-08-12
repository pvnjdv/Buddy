import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../models/flow_models.dart';
import '../config/api_config.dart';

class FlowService {
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

  static Future<ProjectFlow> createProjectFlow({
    required String title,
    required String description,
    required List<FlowCheckpoint> checkpoints,
    String estimatedDuration = '1 week',
    FlowDifficulty difficulty = FlowDifficulty.medium,
    List<String> tags = const [],
  }) async {
    try {
      final token = await AuthService.getToken();
      final flow = ProjectFlow(
        id: '', // Will be set by backend
        title: title,
        description: description,
        checkpoints: checkpoints,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        estimatedDuration: estimatedDuration,
        difficulty: difficulty,
        tags: tags,
      );

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/flows/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(flow.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ProjectFlow.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create flow: ${response.statusCode}');
      }
    } catch (e) {
      // Save flow locally when API is not available
      final localFlow = ProjectFlow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        checkpoints: checkpoints,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        estimatedDuration: estimatedDuration,
        difficulty: difficulty,
        tags: tags,
      );

      // Add to local storage
      await _addFlowLocally(localFlow);

      return localFlow;
    }
  }

  static Future<ProjectFlow> updateProjectFlow(ProjectFlow flow) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/flows/${flow.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(flow.toJson()),
      );

      if (response.statusCode == 200) {
        return ProjectFlow.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update flow: ${response.statusCode}');
      }
    } catch (e) {
      // Update flow locally when API is not available
      final updatedFlow = flow.copyWith(updatedAt: DateTime.now());
      await _updateFlowLocally(updatedFlow);
      return updatedFlow;
    }
  }

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
        // Also try to delete from local storage in case it exists there too
        await _deleteFlowLocally(flowId);
        return true;
      } else {
        throw Exception('Failed to delete flow: ${response.statusCode}');
      }
    } catch (e) {
      // Delete from local storage when API is not available
      await _deleteFlowLocally(flowId);
      return true;
    }
  }

  static Future<ProjectFlow> updateCheckpointStatus(
    String flowId,
    String checkpointId,
    bool isCompleted,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.patch(
        Uri.parse(
          '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'is_completed': isCompleted,
          'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
        }),
      );

      if (response.statusCode == 200) {
        return ProjectFlow.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update checkpoint: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update checkpoint: $e');
    }
  }

  static Future<String> getCheckpointHelp(
    String flowId,
    String checkpointId,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/flows/$flowId/checkpoints/$checkpointId/help',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['help'] ?? 'No help available for this checkpoint.';
      } else {
        throw Exception(
          'Failed to get checkpoint help: ${response.statusCode}',
        );
      }
    } catch (e) {
      return 'Unable to get help at this time. Please try again later.';
    }
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

  // Alarms Management
  static const String _alarmsKey = 'user_alarms';

  static Future<List<FlowAlarm>> getAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsString = prefs.getString(_alarmsKey);
      if (alarmsString != null) {
        final List<dynamic> alarmsJson = jsonDecode(alarmsString);
        return alarmsJson.map((json) => FlowAlarm.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error reading alarms: $e');
    }
    return [];
  }

  static Future<void> _saveAlarmsLocally(List<FlowAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = alarms.map((alarm) => alarm.toJson()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
  }

  static Future<FlowAlarm> createAlarm(FlowAlarm alarm) async {
    try {
      final existingAlarms = await getAlarms();
      existingAlarms.add(alarm);
      await _saveAlarmsLocally(existingAlarms);
      return alarm;
    } catch (e) {
      throw Exception('Failed to create alarm: $e');
    }
  }

  static Future<FlowAlarm> updateAlarm(FlowAlarm alarm) async {
    try {
      final existingAlarms = await getAlarms();
      final index = existingAlarms.indexWhere((a) => a.id == alarm.id);
      if (index != -1) {
        existingAlarms[index] = alarm;
        await _saveAlarmsLocally(existingAlarms);
        return alarm;
      } else {
        throw Exception('Alarm not found');
      }
    } catch (e) {
      throw Exception('Failed to update alarm: $e');
    }
  }

  static Future<void> deleteAlarm(String alarmId) async {
    try {
      final existingAlarms = await getAlarms();
      existingAlarms.removeWhere((alarm) => alarm.id == alarmId);
      await _saveAlarmsLocally(existingAlarms);
    } catch (e) {
      throw Exception('Failed to delete alarm: $e');
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
}

// Enhanced Chat Service for WhatsApp-like functionality
class EnhancedChatService {
  static Future<List<ChatContact>> getContacts() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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

  static Future<List<ChatMessage>> getMessages(String contactId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chats/$contactId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'current_user', // Replace with actual user ID
        receiverId: contactId,
        content: content,
        type: type,
        timestamp: DateTime.now(),
      );

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chats/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(message.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessage.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      // Return the message with current timestamp for offline mode
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

  // Notes Management
  static const String _notesKey = 'user_notes';

  static Future<List<Note>> getNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesString = prefs.getString(_notesKey);
      if (notesString != null) {
        final List<dynamic> notesJson = jsonDecode(notesString);
        return notesJson.map((json) => Note.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error reading notes: $e');
    }
    return [];
  }

  static Future<void> _saveNotesLocally(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((note) => note.toJson()).toList();
    await prefs.setString(_notesKey, jsonEncode(notesJson));
  }

  static Future<Note> createNote(Note note) async {
    try {
      final existingNotes = await getNotes();
      existingNotes.add(note);
      await _saveNotesLocally(existingNotes);
      return note;
    } catch (e) {
      throw Exception('Failed to create note: $e');
    }
  }

  static Future<Note> updateNote(Note note) async {
    try {
      final existingNotes = await getNotes();
      final index = existingNotes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        existingNotes[index] = note;
        await _saveNotesLocally(existingNotes);
        return note;
      } else {
        throw Exception('Note not found');
      }
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  static Future<void> deleteNote(String noteId) async {
    try {
      final existingNotes = await getNotes();
      existingNotes.removeWhere((note) => note.id == noteId);
      await _saveNotesLocally(existingNotes);
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}
